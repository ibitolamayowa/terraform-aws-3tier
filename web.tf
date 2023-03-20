# Create the security group for the web tier
resource "aws_security_group" "web" {
  name_prefix = "web"
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
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
resource "aws_launch_configuration" "web" {
  name                        = "web"
  image_id                    = "ami-0df24e148fdb9f1d8"
  instance_type               = "t2.micro"
  key_name                    = "keypair"
  security_groups             = [aws_security_group.web.id]
  user_data                   = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    cd /var/www/html
    echo "<h1>Company Website</h1>" > index.html
  EOF
  associate_public_ip_address = true
}

# Create the application load balancer
resource "aws_lb" "web" {
  name            = "web"
  internal        = false
  load_balancer_type = "application"
  subnets         = aws_subnet.public[*].id

  tags = {
    Name = "web"
  }
}

# Create the target group
resource "aws_lb_target_group" "web" {
  name_prefix     = "web"
  port            = 80
  protocol        = "HTTP"
  vpc_id          = aws_vpc.aws_vpc.id

  health_check {
    interval            = 10
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Create the autoscaling group
resource "aws_autoscaling_group" "web" {
  name                 = "aws_autoscaling_group_web"
  launch_configuration       = aws_launch_configuration.web.name
  vpc_zone_identifier         = aws_subnet.public[*].id
  max_size                    = 2
  min_size                    = 1
  desired_capacity            = 1
  health_check_grace_period   = 300
  health_check_type           = "ELB"
  termination_policies        = ["Default"]
  tag {
    key                 = "Environment"
    value               = "Web"
    propagate_at_launch = true
  }

  target_group_arns = [aws_lb_target_group.web.arn]

  lifecycle {
    create_before_destroy = true
  }
}

# Create the scale up autoscaling policy
resource "aws_autoscaling_policy" "scale-up" {
  name = "autoscaling-policy-scaleup"
  policy_type = "SimpleScaling"
  autoscaling_group_name  = aws_autoscaling_group.web.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "1"
  cooldown = "300"
  }

# Create the scale up cloudwatch alarm
  resource "aws_cloudwatch_metric_alarm" "cpu-scale-up-alarm" {
  alarm_name = "cpu-scale-up-alarm"
  alarm_description = "cpu-scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "10"
  statistic = "Average"
  threshold = "50"
  dimensions = {
  "AutoScalingGroupName" = aws_autoscaling_group.web.name
  }
  alarm_actions = ["${aws_autoscaling_policy.scale-up.arn}"]
  }

# Create the scale down autoscaling policy
  resource "aws_autoscaling_policy" "scale-down" {
name = "autoscaling-policy-scaledown"
policy_type = "SimpleScaling"
autoscaling_group_name  = aws_autoscaling_group.web.name
adjustment_type = "ChangeInCapacity"
scaling_adjustment = "-1"
cooldown = "300"
}

# Create the scale down cloudwatch alarm
resource "aws_cloudwatch_metric_alarm" "cpu-scale-down-alarm" {
alarm_name = "cpu-scaledown-alarm"
comparison_operator = "LessThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "10"
statistic = "Average"
threshold = "49"
dimensions = {
"AutoScalingGroupName" = aws_autoscaling_group.web.name
}
alarm_actions = ["${aws_autoscaling_policy.scale-down.arn}"]
}