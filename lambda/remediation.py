import json
import boto3

s3 = boto3.client("s3")


def lambda_handler(event, context):
    print("========== AWS CONFIG EVENT RECEIVED ==========")
    print(json.dumps(event, indent=2))

    bucket_name = event.get("bucket_name")

    if not bucket_name:
        detail = event.get("detail", {})
        rule_name = detail.get("configRuleName", "Unknown")
        evaluation_result = detail.get("newEvaluationResult", {})
        compliance_type = evaluation_result.get("complianceType", "Unknown")

        qualifier = evaluation_result.get("evaluationResultIdentifier", {}).get(
            "evaluationResultQualifier", {}
        )
        bucket_name = qualifier.get("resourceId")

        print(f"Config Rule: {rule_name}")
        print(f"Compliance Status: {compliance_type}")
        print(f"Detected Bucket: {bucket_name}")

    if not bucket_name:
        message = "ERROR: Missing bucket name. Could not remediate."
        print(message)
        return {
            "statusCode": 400,
            "body": message
        }

    print("Applying S3 Block Public Access settings...")

    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True
        }
    )

    message = f"SUCCESS: Block Public Access restored for bucket: {bucket_name}"
    print(message)

    return {
        "statusCode": 200,
        "body": message
    }