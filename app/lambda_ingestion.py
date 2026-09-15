import os
import boto3
import pymysql
import requests

from datetime import datetime, timedelta, timezone

USGS_URL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
METRIC_NAMESPACE = "EarthquakeMonitor/SLI"
FRESHNESS_THRESHOLD_SECONDS = 900


def publish_freshness_metrics(endtime, newest_event_timestamp, starttime):
    """Publish the freshness SLI even when ingestion fails upstream."""
    freshness_seconds = (
        max(0, int((endtime - newest_event_timestamp).total_seconds()))
        if newest_event_timestamp
        else int((endtime - starttime).total_seconds())
    )
    freshness_breached = int(freshness_seconds > FRESHNESS_THRESHOLD_SECONDS)

    try:
        boto3.client("cloudwatch").put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {
                    "MetricName": "IngestionFreshnessSeconds",
                    "Dimensions": [
                        {"Name": "Service", "Value": "earthquake-monitor"}
                    ],
                    "Value": freshness_seconds,
                    "Unit": "Seconds",
                    "Timestamp": endtime,
                },
                {
                    "MetricName": "IngestionFreshnessBreached",
                    "Dimensions": [
                        {"Name": "Service", "Value": "earthquake-monitor"}
                    ],
                    "Value": freshness_breached,
                    "Unit": "Count",
                    "Timestamp": endtime,
                },
            ],
        )
    except Exception as metric_error:
        print(f"Unable to publish ingestion freshness metrics: {metric_error}")


# Lambda entry point: fetch recent earthquakes from USGS, persist valid records to RDS,
# and publish SLI metrics so the ingestion pipeline can be monitored and alerted on.
def lambda_handler(event, context):
    # Use a rolling 30-minute window so we ingest the newest events and can calculate
    # whether the feed is stale relative to the current time.
    endtime = datetime.now(timezone.utc)
    starttime = endtime - timedelta(minutes=30)
    inserted_count = 0
    newest_event_timestamp = None
    response = None

    try:
        params = {
            "format": "geojson",
            "starttime": starttime.strftime("%Y-%m-%dT%H:%M:%S"),
            "endtime": endtime.strftime("%Y-%m-%dT%H:%M:%S"),
            "minmagnitude": 0.0,
        }

        response = requests.get(USGS_URL, params=params, timeout=15)

        if response.status_code == 200:
            # USGS returns a GeoJSON feature list; each feature contains earthquake metadata
            # and geometry details that we map into the database schema.
            data = response.json()
            earthquakes = data.get("features", [])

            # Connect to the managed MySQL database that stores the latest quake records.
            connection = pymysql.connect(
                host=os.environ["DB_HOST"],
                user=os.environ["DB_USERNAME"],
                password=os.environ["DB_PASSWORD"],
                database=os.environ["DB_NAME"],
            )

            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        CREATE TABLE IF NOT EXISTS earthquakes (
                            id VARCHAR(64) PRIMARY KEY,
                            time DATETIME NOT NULL,
                            magnitude FLOAT NOT NULL,
                            place VARCHAR(255),
                            latitude FLOAT,
                            longitude FLOAT,
                            depth FLOAT
                        );
                        """
                    )

                    # Ignore malformed records before writing to the database; each earthquake
                    # must have an id, magnitude, timestamp, and a valid 3D coordinate set.
                    for earthquake in earthquakes:
                        properties = earthquake.get("properties") or {}
                        geometry = earthquake.get("geometry") or {}
                        coordinates = geometry.get("coordinates") or []
                        earthquake_id = earthquake.get("id")
                        magnitude = properties.get("mag")
                        event_time = properties.get("time")
                        place = properties.get("place")

                        if (
                            not earthquake_id
                            or magnitude is None
                            or event_time is None
                            or len(coordinates) != 3
                            or any(value is None for value in coordinates)
                        ):
                            continue

                        time = datetime.fromtimestamp(
                            event_time / 1000, timezone.utc
                        ).strftime("%Y-%m-%d %H:%M:%S")
                        event_timestamp = datetime.fromtimestamp(
                            event_time / 1000, timezone.utc
                        )
                        if (
                            newest_event_timestamp is None
                            or event_timestamp > newest_event_timestamp
                        ):
                            newest_event_timestamp = event_timestamp
                        latitude, longitude, depth = coordinates

                        sql = """
                            INSERT INTO earthquakes (id, time, magnitude, place, latitude, longitude, depth)
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                            ON DUPLICATE KEY UPDATE
                                time = VALUES(time), magnitude = VALUES(magnitude),
                                place = VALUES(place), latitude = VALUES(latitude),
                                longitude = VALUES(longitude), depth = VALUES(depth)
                        """
                        cursor.execute(
                            sql,
                            (
                                earthquake_id,
                                time,
                                magnitude,
                                place,
                                latitude,
                                longitude,
                                depth,
                            ),
                        )
                        inserted_count += 1

                    connection.commit()
            finally:
                connection.close()

            return {
                "statusCode": 200,
                "body": f"Successfully ingested {inserted_count} earthquake records.",
            }

        return {
            "statusCode": response.status_code,
            "body": f"Error fetching data from USGS API: {response.text}",
        }
    except Exception as exc:
        print(f"Error fetching or ingesting earthquake data: {exc}")
        return {
            "statusCode": 500,
            "body": f"Error fetching or ingesting earthquake data: {exc}",
        }
    finally:
        publish_freshness_metrics(endtime, newest_event_timestamp, starttime)
