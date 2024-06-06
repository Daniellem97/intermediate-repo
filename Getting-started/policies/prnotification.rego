package spacelift

import future.keywords

run_link := sprintf("https://%s.app.spacelift.io/stack/%s/run/%s", [input.account.name, input.run_updated.stack.id, input.run_updated.run.id])

# Helper Function to Trim Spaces
trim_spaces(s) := trim(trim(s, "\n"), " ")

# Policy Information Section with Emojis
generate_policy_rows := {row |
    policy := input.run_updated.policy_receipts[_]
    outcome_emoji := get_outcome_emoji(policy.outcome)
    row := sprintf("| %s | %s | %s %s |", [policy.name, policy.type, outcome_emoji, policy.outcome])
}
policy_info := concat("\n", ["### Policy Information\n\n| Policy Name | Policy Type | Outcome |\n| --- | --- | --- |", concat("\n", generate_policy_rows)])

get_outcome_emoji(outcome) = emoji {
  outcome == "deny"
  emoji := ":x:"
} else = emoji {
  outcome == "reject"
  emoji := ":x:"
} else = emoji {
  outcome == "approve"
  emoji := ":white_check_mark:"
} else = emoji {
  outcome == "allow"
  emoji := ":white_check_mark:"
} else = emoji {
  outcome == "undecided"
  emoji := ":shrug:"
} else = emoji {
  emoji := ""
}

# check if the run failed due to any deny or reject policy
any_deny_or_reject {
    policy_receipt := input.run_updated.policy_receipts[_]
    policy_receipt.outcome == "deny"
}

any_deny_or_reject {
    policy_receipt := input.run_updated.policy_receipts[_]
    policy_receipt.outcome == "reject"
}

# Extract and format plan policy decisions
format_plan_decisions := concat("\n", ["\n\n### Plan Policy Decisions\n\n", concat("\n", [sprintf("- %s", [decision]) | 
    decision := input.run_updated.plan_policy_decision.deny[_]
])])

# Helper function to check if a phase is present
phase_present(phase_name) {
    some i
    input.run_updated.timing[i].state == phase_name
}

# Determine which logs to include based on the phases present
logs_to_include := logs {
    not phase_present("INITIALIZING")
    not phase_present("PLANNING")
    logs := "spacelift::logs::preparing"
} else = logs {
    phase_present("INITIALIZING")
    not phase_present("PLANNING")
    logs := "spacelift::logs::initializing"
} else = logs {
    logs := "spacelift::logs::planning"
}


#Run Failed due to Policy
pull_request[{"commit": input.run_updated.run.commit.hash, "body": message}] {
    input.run_updated.run.state == "FAILED"
    any_deny_or_reject
    message := trim_spaces(concat("\n", [sprintf("Your run has failed due to the following reason: %s. [Run Link](%s)", [input.run_updated.note, run_link]), policy_info, format_plan_decisions]))
}

# Helper function to find the last phase before failure
last_phase_before_failure() = last_phase {
    # Extract all phases into a list
    phases := [phase | timing := input.run_updated.timing[_]; phase := timing.state]
    
    # Assume the last phase in the list is the failure point
    last_phase := phases[count(phases) - 1]
}

# Run Failed (not due to Policy) with dynamic log selection and failure phase
pull_request[{"commit": input.run_updated.run.commit.hash, "body": message}] {
    input.run_updated.run.state == "FAILED"
    not any_deny_or_reject

    # Determine the last phase before failure
    failure_phase := last_phase_before_failure()

    # Define logs_dropdown based on the presence of phases
    logs_dropdown := sprintf("<details><summary>Logs</summary>\n%s\n</details>\n", [logs_to_include])

    # Construct the message to include information about the failure phase
    message := trim_spaces(concat("\n", [
        sprintf("This run failed during the %s phase. For more details, you can review the run [here](%s):", [failure_phase, run_link]),
        logs_dropdown
    ]))
}
header := sprintf("### Resource changes ([link](https://%s.app.spacelift.io/stack/%s/run/%s))\n\n![add](https://img.shields.io/badge/add-%d-brightgreen) ![change](https://img.shields.io/badge/change-%d-yellow) ![destroy](https://img.shields.io/badge/destroy-%d-red)\n\n| Action | Resource | Changes |\n| --- | --- | --- |", [input.account.name, input.run_updated.stack.id, input.run_updated.run.id, count(added), count(changed), count(deleted)])

addedresources := concat("\n", added)
changedresources := concat("\n", changed)
deletedresources := concat("\n", deleted)

added contains row if {
  some x in input.run_updated.run.changes

  row := sprintf("| Added | `%s` | <details><summary>Value</summary>`%s`</details> |", [x.entity.address, x.entity.data.values])
  x.action == "added"
  x.entity.entity_type == "resource"
}

changed contains row if {
  some x in input.run_updated.run.changes

  row := sprintf("| Changed | `%s` | <details><summary>New value</summary>`%s`</details> |", [x.entity.address, x.entity.data.values])
  x.entity.entity_type == "resource"

  any([x.action == "changed", x.action == "destroy-Before-create-replaced", x.action == "create-Before-destroy-replaced"])
}

deleted contains row if {
  some x in input.run_updated.run.changes
  row := sprintf("| Deleted | `%s` | :x: |", [x.entity.address])
  x.entity.entity_type == "resource"
  x.action == "deleted"
}

# Run Finished Successfully
pull_request[{"commit": input.run_updated.run.commit.hash, "body": message}] {
    input.run_updated.run.state == "FINISHED"
    not any_deny_or_reject

    # Generate the header and resource changes details
    resource_changes_details := concat("\n", [
        header,  # Header includes the summary of changes (add/change/delete)
        addedresources,  # Details of added resources
        changedresources,  # Details of changed resources
        deletedresources  # Details of deleted resources
    ])

    # Construct the final message without run_link and sprintf
    final_message := concat("\n", [
        "This run finished successfully, you can review the resource changes below:",
        resource_changes_details, policy_info
    ])

    # Use trim_spaces to clean up the final message
    message := trim_spaces(final_message)
}
sample := true
