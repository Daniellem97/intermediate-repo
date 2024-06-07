package spacelift

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# regal ignore:line-length
run_link := sprintf("https://%s.app.spacelift.io/stack/%s/run/%s", [input.account.name, input.run_updated.stack.id, input.run_updated.run.id])

# Helper Function to Trim Spaces
trim_spaces(s) := trim(trim(s, "\n"), " ")

generate_policy_rows := [row |
	some policy_index

	# regal ignore:prefer-some-in-iteration
	policy := input.run_updated.policy_receipts[policy_index]
	outcome_emoji := decide_outcome_emoji(policy.outcome)

	row := sprintf("| %s | %s | %s %s |", [policy.name, policy.type, outcome_emoji, policy.outcome])
]

# regal ignore:line-length
policy_info := sprintf("### Policy Information\n\n| Policy Name | Policy Type | Outcome |\n| --- | --- | --- |\n%s", [concat("\n", generate_policy_rows)])

decide_outcome_emoji(outcome) := emoji if {
	outcome == "deny"
	emoji := ":x:"
} else := emoji if {
	outcome == "reject"
	emoji := ":x:"
} else := emoji if {
	outcome == "approve"
	emoji := ":white_check_mark:"
} else := emoji if {
	outcome == "allow"
	emoji := ":white_check_mark:"
} else := emoji if {
	outcome == "undecided"
	emoji := ":shrug:"
} else := emoji if {
	emoji := ""
}

# check if the run failed due to any deny or reject policy
any_deny_or_reject if {
	some policy_receipt in input.run_updated.policy_receipts
	policy_receipt.outcome == "deny"
}

any_deny_or_reject if {
	some policy_receipt in input.run_updated.policy_receipts
	policy_receipt.outcome == "reject"
}

# Extract and format plan policy decisions
# regal ignore:line-length
format_plan_decisions := concat("\n", ["\n\n### Plan Policy Decisions\n\n", concat("\n", [sprintf("- %s", [decision]) |
	some decision in input.run_updated.plan_policy_decision.deny
])])

# Helper function to check if a phase is present
phase_present(phase_name) if {
	some i

	# regal ignore:prefer-some-in-iteration
	input.run_updated.timing[i].state == phase_name
}

# Determine which logs to include based on the phases present
logs_to_include := logs if {
	not phase_present("INITIALIZING")
	not phase_present("PLANNING")
	logs := "spacelift::logs::preparing"
} else := logs if {
	phase_present("INITIALIZING")
	not phase_present("PLANNING")
	logs := "spacelift::logs::initializing"
} else := logs if {
	logs := "spacelift::logs::planning"
}

# Run Failed due to Policy
pull_request contains {"commit": input.run_updated.run.commit.hash, "body": message} if {
	input.run_updated.run.state == "FAILED"
	input.run_updated.run.type == "PROPOSED"
	any_deny_or_reject

	# regal ignore:line-length
	message := trim_spaces(concat("\n", [sprintf("Your run has failed due to the following reason: %s. [Run Link](%s)", [input.run_updated.note, run_link]), policy_info, format_plan_decisions]))
}

# Helper function to find the last phase before failure
last_phase_before_failure := last_phase if {
	# Extract all phases into a list
	phases := [phase | some timing in input.run_updated.timing; phase := timing.state]

	# Assume the last phase in the list is the failure point
	last_phase := phases[count(phases) - 1]
}

# Run Failed (not due to Policy) with dynamic log selection and failure phase
pull_request contains {"commit": input.run_updated.run.commit.hash, "body": message} if {
	input.run_updated.run.state == "FAILED"
	input.run_updated.run.type == "PROPOSED"
	not any_deny_or_reject

	# Determine the last phase before failure
	failure_phase := last_phase_before_failure()

	# Define logs_dropdown based on the presence of phases
	logs_dropdown := sprintf("<details><summary>Logs</summary>\n%s\n</details>\n", [logs_to_include])

	# Construct the message to include information about the failure phase
	message := trim_spaces(concat("\n", [
		# regal ignore:line-length
		sprintf("This run failed during the %s phase. For more details, you can review the run [here](%s):", [failure_phase, run_link]),
		logs_dropdown,
	]))
}

# regal ignore:line-length
header := sprintf("### Resource changes ([link](https://%s.app.spacelift.io/stack/%s/run/%s))\n\n![add](https://img.shields.io/badge/add-%d-brightgreen) ![change](https://img.shields.io/badge/change-%d-yellow) ![destroy](https://img.shields.io/badge/destroy-%d-red)\n\n| Action | Resource | Changes |\n| --- | --- | --- |", [input.account.name, input.run_updated.stack.id, input.run_updated.run.id, count(added), count(changed), count(deleted)])

addedresources := concat("\n", added)

changedresources := concat("\n", changed)

deletedresources := concat("\n", deleted)

added contains row if {
	some x in input.run_updated.run.changes

	# regal ignore:line-length
	row := sprintf("| Added | `%s` | <details><summary>Value</summary>`%s`</details> |", [x.entity.address, x.entity.data.values])
	x.action == "added"
	x.entity.entity_type == "resource"
}

changed contains row if {
	some x in input.run_updated.run.changes

	# regal ignore:line-length
	row := sprintf("| Changed | `%s` | <details><summary>New value</summary>`%s`</details> |", [x.entity.address, x.entity.data.values])
	x.entity.entity_type == "resource"

	# regal ignore:line-length
	any([x.action == "changed", x.action == "destroy-Before-create-replaced", x.action == "create-Before-destroy-replaced"])
}

deleted contains row if {
	some x in input.run_updated.run.changes
	row := sprintf("| Deleted | `%s` | :x: |", [x.entity.address])
	x.entity.entity_type == "resource"
	x.action == "deleted"
}

# Run Finished Successfully
pull_request contains {"commit": input.run_updated.run.commit.hash, "body": message} if {
	input.run_updated.run.state == "FINISHED"
	input.run_updated.run.type == "PROPOSED"
	not any_deny_or_reject

	# Generate the header and resource changes details
	resource_changes_details := concat("\n", [
		header, # Header includes the summary of changes (add/change/delete)
		addedresources, # Details of added resources
		changedresources, # Details of changed resources
		deletedresources, # Details of deleted resources
	])

	# Construct the final message without run_link and sprintf
	final_message := concat("\n", [
		"This run finished successfully, you can review the resource changes below:",
		resource_changes_details, policy_info,
	])

	# Use trim_spaces to clean up the final message
	message := trim_spaces(final_message)
}

sample := true

