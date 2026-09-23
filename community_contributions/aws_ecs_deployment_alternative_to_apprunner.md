# Consultation App Deployment Alternative to App Runner

## Set up IAM User, Group, and Permission Policies
In the AWS Services search bar, type **IAM** and open the IAM service.

1. Create a new IAM group named `BroadAIEngineerAccess`.
2. Create a new IAM user named `aiengineer` and add it to the `BroadAIEngineerAccess` group.
3. Attach the following six permission policies to the `BroadAIEngineerAccess` group:
    - `AmazonEC2ContainerRegistryFullAccess`
    - `AmazonECS_FullAccess`
    - `AmazonECSTaskExecutionRolePolicy`
    - `CloudWatchLogsFullAccess`
    - `IAMFullAccess`
    - `IAMUserChangePassword`

> **Note:** This setup is intentionally broad for course progression and temporary deployments. In production, use least-privilege IAM policies.

## Create an Amazon ECS Deployment (Alternative to App Runner)
In the AWS Services search bar, type **ECS** and open the ECS service.

This setup provisions your application on **AWS Fargate** using **Amazon ECS Express**.

## Full Setup of the Consultation App Using Amazon ECS (Express)
After pushing your container image to ECR, deploy it using Amazon ECS Express:

1. In the AWS Console, open **ECS**.
2. In the left sidebar, click **Express mode**.
3. In **Let’s set up your app**, under **Image URI**, click **Browse ECR images**.
4. In the modal, choose your `consultation-app` repository from **Private repository**.
5. Select image tag `latest`, then click **Select image**.
6. Open **Additional configurations — optional**.
7. For **Cluster**, select `default` (ECS creates it if needed).
8. Set:
    - **Container port**: `8000`
    - **Health check path**: `/health`
9. Add environment variables:
    - `CLERK_SECRET_KEY` = (your value)
    - `CLERK_JWKS_URL` = (your value)
    - `OPENAI_API_KEY` = (your value)

   _Tip: Use **Bulk edit** to paste all values at once._
10. For **Task role**, select `ecsTaskExecutionRole` from the dropdown (per this course setup).
11. In **Compute**, select:
    - **CPU**: `.25 vCPU`
    - **Memory**: `.5 GB`
12. In **Auto scaling**, select:
    - **ECS service metric**: `Request count per target`
    - **Target value**: `10`
    - **Minimum number of tasks**: `1`
    - **Maximum number of tasks**: `1`
    _This intentionally keeps the service at one task for this lesson._
13. Click **Create service**, then wait a few minutes for provisioning.

When the service is ready, find the Application URL in the Express service overview and open it.

### Monitoring and Debugging
From **ECS > Express services**, open your service details page to monitor health and logs.

If you see errors in the **Observability** tab, you may need additional IAM permissions to access those features. In some course environments, root-user access may be used temporarily; however, using an IAM user/group with explicit permissions is preferred where possible.

CloudWatch (**View in CloudWatch**) may also require additional IAM permissions before logs are visible.

### If Health Checks Are OK but the App Does Not Load
If health checks are passing but the app still does not appear at the Application URL, the ECS Express configuration may be incorrect.

Try creating a new **service revision** and redeploying, rather than deleting and rebuilding from scratch.

For more information, see [Deploy Amazon ECS services by replacing tasks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html?icmpid=docs_ecs_hp-service-deployment-details-failure-information).
