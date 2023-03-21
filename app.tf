# Create the security group for the app tier
resource "aws_security_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.aws_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the launch configuration
resource "aws_launch_configuration" "app" {
  name                        = "app"
  image_id                    = "ami-0df24e148fdb9f1d8"
  instance_type               = "t2.micro"
  key_name                    = "keypair"
  security_groups             = [aws_security_group.app.id]
  associate_public_ip_address = false
}

# Create the application load balancer
resource "aws_lb" "app" {
  name            = "app"
  internal        = true
  load_balancer_type = "application"
  subnets            = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    Name = "app"
  }
}

# Create the target group
resource "aws_lb_target_group" "app" {
  name_prefix     = "app"
  port            = 80
  protocol        = "HTTP"
  vpc_id          = aws_vpc.aws_vpc.id
}

# Create the autoscaling group
resource "aws_autoscaling_group" "app" {
  name                 = "aws_autoscaling_group_app"
  launch_configuration       = aws_launch_configuration.app.name
  vpc_zone_identifier         = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  max_size                    = 2
  min_size                    = 1
  desired_capacity            = 1
  health_check_grace_period   = 300
  health_check_type           = "ELB"
  termination_policies        = ["Default"]
  tag {
    key                 = "Environment"
    value               = "app"
    propagate_at_launch = true
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  lifecycle {
    create_before_destroy = true
  }
}

# Create the scale up autoscaling policy
resource "aws_autoscaling_policy" "app-scale-up" {
  name = "autoscaling-policy-scaleup-app"
  policy_type = "SimpleScaling"
  autoscaling_group_name  = aws_autoscaling_group.app.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "1"
  cooldown = "300"
  }

# Create the scale up cloudwatch alarm
  resource "aws_cloudwatch_metric_alarm" "cpu-scale-up-app-alarm" {
  alarm_name = "cpu-scale-up-app-alarm"
  alarm_description = "cpu-scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "10"
  statistic = "Average"
  threshold = "50"
  dimensions = {
  "AutoScalingGroupName" = aws_autoscaling_group.app.name
  }
  alarm_actions = ["${aws_autoscaling_policy.scale-up.arn}"]
  }

# Create the scale down autoscaling policy
resource "aws_autoscaling_policy" "scale-down-app" {
name = "autoscaling-policy-scaledown-app"
policy_type = "SimpleScaling"
autoscaling_group_name  = aws_autoscaling_group.app.name
adjustment_type = "ChangeInCapacity"
scaling_adjustment = "-1"
cooldown = "300"
}

# Create the scale down cloudwatch alarm
resource "aws_cloudwatch_metric_alarm" "cpu-scale-down-app-alarm" {
alarm_name = "cpu-scaledown-app-alarm"
comparison_operator = "LessThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "10"
statistic = "Average"
threshold = "49"
dimensions = {
"AutoScalingGroupName" = aws_autoscaling_group.app.name
}
alarm_actions = ["${aws_autoscaling_policy.scale-down.arn}"]
}

output "app_private_subnet_ids" {
  value = [aws_subnet.private[0].id, aws_subnet.private[1].id]
}