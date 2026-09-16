package terraform.policy


default allow = false


allow if {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
}

