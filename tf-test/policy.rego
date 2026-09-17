package terraform.policy


default allow = false


allow if {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
  # input.configuration.root_module.resources[_].type == "aws_s3_bucket"
}

