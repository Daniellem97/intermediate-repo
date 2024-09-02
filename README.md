# Intermediate Repository

This repository assumes familiarity with the [starter repository](https://github.com/spacelift-io/terraform-starter) and core concepts. Basic setup should already be completed.
This repository focuses solely on terraform and AWS.

## Topics Covered:

<details>
<summary>Runtime Configuration</summary>

Runtime Configuration allows you to set up and manage configurations that define how your infrastructure is deployed and managed. It helps you control various aspects such as environment variables, command execution, and more.

More information: [Runtime Configuration](https://docs.spacelift.io/concepts/configuration/runtime-configuration/#:~:text=The%20top%20level%20of%20the,using%20this%20source%20code%20repository)

</details>

<details>
<summary>AWS Cloud Integration</summary>

AWS Cloud Integration enables you to connect your Spacelift account with your AWS environment, facilitating automated deployments and infrastructure management.

More information: [AWS Cloud Integration](https://docs.spacelift.io/integrations/cloud-providers/aws#amazon-web-services-aws)

</details>

<details>
<summary>Private Workers</summary>

Private Workers allow you to run jobs on dedicated, isolated instances within your VPC, enhancing security and compliance.

More information: [Private Workers](https://docs.spacelift.io/concepts/vcs-agent-pools.html#private-workers)

</details>

<details>
<summary>Drift Detection</summary>

Drift Detection helps identify changes in your infrastructure that occur outside of your Spacelift configurations, ensuring that your deployed infrastructure remains consistent with your defined state.

More information: [Drift Detection](https://docs.spacelift.io/concepts/stack/drift-detection.html)

</details>

<details>
<summary>Stack Dependencies</summary>

Stack Dependencies manage the relationships between different stacks, ensuring that dependencies are respected and resources are provisioned or destroyed in the correct order.

More information: [Stack Dependencies](https://docs.spacelift.io/concepts/stack/stack-dependencies.html)

</details>

<details>
<summary>Contexts with Auto Attachment and Hooks</summary>

Contexts allow you to define reusable sets of environment variables and settings that can be automatically attached to stacks. Hooks enable you to run custom scripts or commands at various points in the stack lifecycle.

More information: [Contexts with Auto Attachment and Hooks](https://docs.spacelift.io/concepts/configuration/context.html)

</details>

<details>
<summary>More Complex Policies and Integrating with Security Tools</summary>

This section covers advanced policy configurations and the integration of security tools like Checkov to enhance your infrastructure's security posture.

More information: [Integrating Security Tools](https://spacelift.io/blog/integrating-security-tools-with-spacelift#checkov-integration)

</details>

## Step 1: Fork and Create Stack

1. Fork this repository.
2. Via the UI, create an administrative stack in the root space pointing to this repository.
3. Name this stack `intermediate-repo`.
3. Set the project root as `Getting-started`.

The project root points to the directory within the repo where the project should start executing. This is especially useful for monorepos.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/6#issue-2339661550)

## Step 2: Add Variables and Trigger Stack

1. Add two variables to this stack:
   - `TF_VAR_role_name`
   - `TF_VAR_role_arn`

   Follow the [setup guide from AWS](https://docs.spacelift.io/integrations/cloud-providers/aws#setup-guide) to retrieve these values. 
   
   **Note:** Do not manually create the Cloud integration, the stack will use these environment variables to do this for you.

3. Trigger the `intermediate-repo` stack.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/7#issue-2339665046)

<details>
<summary>Explanation of resources being created:</summary>

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
   - `TF_VAR_spacelift_api_key_secret`
   - `TF_VAR_spacelift_api_endpoint` (https://(youraccountname).app.spacelift.io)

These variables are needed to allow for autoscaling.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/8#issue-2339665866)

<details>
<summary>Explanation of Private Worker Stack</summary>

- This stack is using the following [module](https://github.com/spacelift-io/terraform-aws-spacelift-workerpool-on-ec2)
- The `Intermediate-repo` stack has already added variables relating to the worker pool and a mounted file with the IP addresses needed.
- Triggering a run on this stack will:
  - Create your VPC, subnets, and a security group with unrestricted egress and restricted ingress to the IP addresses needed.
  - Create your EC2 instance private worker.

</details>

## Step 4: Trigger Drift Detection Stack

1. Trigger a run on the drift detection stack.
2. Optionally add `TF_VAR_drift_detection_schedule` environment variable (defaults to every 15 minutes). Example Value : `["*/15 * * * *"]` for every 15 minutes
3. Trigger the stack with drift detection enabled. It will create a context. 
4. Manually add a label to this context via the UI.
5. After 15 minutes, check if an reconcile run was started.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/9#issue-2339667726)

## Step 5: Trigger Stack Dependencies Stack

1. Trigger the `Dependencies stack` stack.
2. Once the stack is finished, trigger a run on the Infra stack to create the `DB_CONNECTION_STRING`, which will then automatically start a run in the app stack and save this output as an input to be used.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/10#issue-2339668651

<details>
<summary>Explanation of Stack Dependencies</summary>

- This stack will create two stacks and establish a stack dependency between them with a shared output.
- The Infra stack will output `DB_CONNECTION_STRING` and save it as an input of `TF_VAR_APP_DB_URL` to the App stack.

</details>

## Step 6: Optional Activities

<details>
<summary>Activity 1: Contexts and Policies</summary>

- Our context `Tflint` and policy `Tflintchecker` were both created with the label `autoattach:tflint`.
- Add the label `tflint` to the stack `Dependencies stack` and watch both the context and policy get attached to the stack.
- Trigger a run on this stack. The hooks will now install `tflint`, run the tool, and then save these findings in a third-party metadata section of our policy input, which we then use in our policy.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/11#issue-2339669346)

More information: [Integrating Security Tools with Spacelift](https://spacelift.io/blog/integrating-security-tools-with-spacelift)

</details>

<details>
<summary>Activity 2: Pull Request Notification</summary>

- Open a pull request against any of the stacks.
- Wait for a comment from the PR notification policy that was created. It will add a comment based on the following conditions:

  - If the stack has failed in any stage not due to a policy, it will post the relevant logs.
  - If the stack has failed due to a policy, it will give a summary of the policies and any relevant deny messages.
  - If the stack has finished successfully, it will post a summary of the run, the policies used, and any changes to be made.
    
[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/12#issue-2339669959)

More information: [Notification Policy](https://docs.spacelift.io/concepts/policy/notification-policy)

</details>

## Step 7: Destroy Resources

1. Run `terraform destroy -auto-approve` as a task in the `intermediate-repo` stack.

[Here is a walkthrough video](https://github.com/Daniellem97/intermediate-repo/issues/13#issue-2339670633)


<details>
<summary>Explanation of Resource Destruction</summary>

- Our stack has also created stack-destructors, which handle the execution of destroying the resources on our created stacks first to ensure all resources are destroyed.

More reading: [Ordered Stack Creation and Deletion](https://docs.spacelift.io/concepts/stack/stack-dependencies#ordered-stack-creation-and-deletion)

</details>
