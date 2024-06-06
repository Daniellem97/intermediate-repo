# Intermediate Repository

This repository assumes familiarity with the [starter repository](https://github.com/spacelift-io/terraform-starter) and core concepts. Basic setup should already be completed.
This repository focuses solely on terraform and AWS.

## Topics Covered:

<details>
<summary>### Runtime Configuration</summary>

Runtime Configuration allows you to set up and manage configurations that define how your infrastructure is deployed and managed. It helps you control various aspects such as environment variables, command execution, and more.

More information: [Runtime Configuration](https://docs.spacelift.io/concepts/configuration/runtime-configuration/#:~:text=The%20top%20level%20of%20the,using%20this%20source%20code%20repository)

</details>

### AWS Cloud Integration

<details>
<summary>Click to expand</summary>

AWS Cloud Integration enables you to connect your Spacelift account with your AWS environment, facilitating automated deployments and infrastructure management.

More information: [AWS Cloud Integration](https://docs.spacelift.io/integrations/cloud-providers/aws#amazon-web-services-aws)

</details>

### Private Workers

<details>
<summary>Click to expand</summary>

Private Workers allow you to run jobs on dedicated, isolated instances within your VPC, enhancing security and compliance.

More information: [Private Workers](https://docs.spacelift.io/concepts/vcs-agent-pools.html#private-workers)

</details>

### Drift Detection

<details>
<summary>Click to expand</summary>

Drift Detection helps identify changes in your infrastructure that occur outside of your Spacelift configurations, ensuring that your deployed infrastructure remains consistent with your defined state.

More information: [Drift Detection](https://docs.spacelift.io/concepts/stack/drift-detection.html)

</details>

### Stack Dependencies

<details>
<summary>Click to expand</summary>

Stack Dependencies manage the relationships between different stacks, ensuring that dependencies are respected and resources are provisioned or destroyed in the correct order.

More information: [Stack Dependencies](https://docs.spacelift.io/concepts/stack/stack-dependencies.html)

</details>

### Contexts with Auto Attachment and Hooks

<details>
<summary>Click to expand</summary>

Contexts allow you to define reusable sets of environment variables and settings that can be automatically attached to stacks. Hooks enable you to run custom scripts or commands at various points in the stack lifecycle.

More information: [Contexts with Auto Attachment and Hooks](https://docs.spacelift.io/concepts/configuration/context.html)

</details>

### More Complex Policies and Integrating with Security Tools

<details>
<summary>Click to expand</summary>

This section covers advanced policy configurations and the integration of security tools like Checkov to enhance your infrastructure's security posture.

More information: [Integrating Security Tools](https://spacelift.io/blog/integrating-security-tools-with-spacelift#checkov-integration)

</details>

## Step 1: Fork and Create Stack

1. Fork this repository.
2. Create an administrative stack in the root space pointing to this repository.
3. Set the project root as "Getting-Started".

The project root points to the directory within the repo where the project should start executing. This is especially useful for monorepos.

## Step 2: Add Variables and Trigger Stack

1. Add two variables to this stack:
   - `TF_VAR_role_name`
   - `TF_VAR_role_arn`

   Follow the [setup guide from AWS](https://docs.spacelift.io/integrations/cloud-providers/aws#setup-guide) to retrieve these values.

2. Trigger this stack.

### Explanation of resources being created:

<details>
<summary>Click to expand</summary>

- Creating a space for all our resources to go into, isolating it from the rest of our account.
- Creating a stack to use an AWS EC2 private worker module.
- Creating a stack with a drift detection schedule.
- Creating two stacks with a stack dependency.
- Creating two policies which will be discussed further later.
- Mounting a file containing a JSON-encoded list of Spacelift's outgoing IPs.
- Creating a worker pool with the private key and worker pool config.
- Setting environment variables for the worker pool ID to be used in other stacks to utilize the private worker pool.
- Setting environment variables for the private key and worker pool config.

**Note:** We are using a runtime config file with the stack default AWS region set to `eu-west-1`, which will apply to all stacks.

</details>

## Step 3: Create API Key and Configure Private Worker Stack

1. Create an admin API key in the intermediate-repo space.
2. Save these variables on the private worker stack:
   - `TF_VAR_spacelift_api_key_id`
   - `TF_VAR_spacelift_key_secret`
   - `TF_VAR_spacelift_api_endpoint` (https://<accountname>.app.spacelift.io)

These variables are needed to allow for autoscaling.

### Explanation of Private Worker Stack

<details>
<summary>Click to expand</summary>

- The `Getting-Started` stack has already added variables relating to the worker pool and a mounted file with the IP addresses needed.
- Triggering a run on this stack will:
  - Create your VPC, subnets, and a security group with unrestricted egress and restricted ingress to the IP addresses needed.
  - Create your EC2 instance private worker.

</details>

## Step 4: Trigger Drift Detection Stack

1. Trigger a run on the drift detection stack.
2. Optionally add `TF_VAR_drift_detection_schedule` environment variable (defaults to every 15 minutes).

### Explanation of Drift Detection

<details>
<summary>Click to expand</summary>

- This stack will create a stack with a drift detection schedule that runs every 15 minutes.
- Optional activity: Trigger the stack with drift detection enabled. It will create a context. Manually add a label to this context via the UI and check if the drift detection run notices the drift.

</details>

## Step 5: Trigger Stack Dependencies Stack

1. Trigger the stack dependencies stack.

### Explanation of Stack Dependencies

<details>
<summary>Click to expand</summary>

- This stack will create two stacks and establish a stack dependency between them with a shared output.
- The infra stack will output `DB_CONNECTION_STRING` and save it as an input of `TF_VAR_APP_DB_URL` to the APP stack.
- Optional activity: Trigger a run on the infra stack to create the `DB_CONNECTION_STRING`, then automatically start a run in the app stack and save this output as an input to be used.

</details>

## Step 6: Optional Activities

### Activity 1: Pull Request Notification

<details>
<summary>Click to expand</summary>

- Open a pull request against any of the stacks.
- Wait for a comment from the PR notification policy that was created. It will add a comment based on the following conditions:
  - If the stack has failed in any stage not due to a policy, it will post the relevant logs.
  - If the stack has failed due to a policy, it will give a summary of the policies and any relevant deny messages.
  - If the stack has finished successfully, it will post a summary of the run, the policies used, and any changes to be made.

More information: [Notification Policy](https://docs.spacelift.io/concepts/policy/notification-policy)

</details>

### Activity 2: Contexts and Policies

<details>
<summary>Click to expand</summary>

- Our context `Tflint` and policy `Tflintchecker` were both created with the label `autoattach:tflint`.
- Add the label `tflint` to a stack of your choice and watch both the context and policy get attached to the stack.
- Trigger a run on this stack. The hooks will now install `tflint`, run the tool, and save these findings in a third-party metadata section of our policy input, which we then use in our policy.

More information: [Integrating Security Tools with Spacelift](https://spacelift.io/blog/integrating-security-tools-with-spacelift)

</details>

### Activity 3: Import Policy from Policy Library

<details>
<summary>Click to expand</summary>

- Import a policy from the policy library via the UI.
- Attach it to the stack.

</details>

## Step 7: Destroy Resources

1. Run `terraform destroy -auto-approve` as a task in the `getting-started` stack.

### Explanation of Resource Destruction

<details>
<summary>Click to expand</summary>

- Our stack has also created stack-destructors, which handle the execution of destroying the resources on our created stacks first to ensure all resources are destroyed.

More reading: [Ordered Stack Creation and Deletion](https://docs.spacelift.io/concepts/stack/stack-dependencies#ordered-stack-creation-and-deletion)

</details>
