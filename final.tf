provider "aws" {
  region = "ap-south-1"
  profile = "engineer_hulk"
}
//Creating a key pair with key name "key"
resource "tls_private_key" "key" {
  algorithm = "RSA"
  
}
resource "aws_key_pair" "key" {
  key_name   = "key"
  public_key = tls_private_key.key.public_key_openssh
  depends_on = 
   [
     tls_private_key.key
   ]
}
//Creating a security group which can allow port 80 for https and port 22 for ssh.
resource "aws_security_group" "security_0616" {
  name        = "security_0616"
  description = "Allow traffic"
    ingress 
        {
    	description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    	}
   ingress 
	{
    	description = "HTTP"
    	from_port   = 80
    	to_port     = 80
    	protocol    = "tcp"
    	cidr_blocks = ["0.0.0.0/0"]
  	}
  egress 
	{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  	}
  tags =
 	{
   	 Name = "security_0616"
  	}
}
resource "aws_instance"  "myin1" {
   ami           = "ami-07a8c73a650069cf3"
   instance_type = "t2.micro"
   key_name	= aws_key_pair.key.key_name
   security_groups =  [ "security_0616" ] 
   tags = 
      {
       Name = "ashutoshtiwariOS1"
      }
   provisioner "remote-exec"
          {
          	connection  
                    {
  			  type     = "ssh"
  			  user     = "ec2-user"
   			  agent    = "false"
		          private_key = tls_private_key.key.private_key_pem
                          host     = aws_instance.myin1.public_ip
                    }
                 inline = 
                         [
   			   "sudo yum install httpd  php git -y","sudo systemctl restart httpd","sudo systemctl enable httpd",  
      "sudo git clone https://github.com/engineerhulk/hybrid_multicloud_computing-task-1-.git /var/www/html/"]
                         ]
          }
}
//Creating one EBS volume
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.myin1.availability_zone
  size              = 2
  tags =
	 {
  	  Name = "ebs1"
  	 }
}
// Attaching this EBS volume with EC2 instance
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.myin1.id
  force_detach = true 
  connection
   {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.key.private_key_pem
    host     = aws_instance.myin1.public_ip
   }
  provisioner "remote-exec"
  {
    inline = 
     [ 
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/engineerhulk/hybrid_multicloud_computing-task-1-.git /var/www/html/"
     ]
  }
}
//Creating one S3 bucket
resource "aws_s3_bucket" "task1bucket" {
	bucket = "task1bucketofashutoshtiwari"
 	acl = "private"
        force_destroy = "true"  
        versioning 
                {
		enabled = true
                }
}
//Deploying image from github repo i.e engineerhulk/image_task1_cloud
resource "null_resource" "localone" {
	depends_on = [aws_s3_bucket.task1bucket,]
	provisioner "remote-exec" 
	{
	inline = [ "sudo git clone https://github.com/engineerhulk/image_task1_cloud.git" ]
  	}
}
//Giving permission for public read
resource "aws_s3_bucket_object" "file_upload" {
	depends_on = [aws_s3_bucket.task1bucket , null_resource.localone]
	bucket = aws_s3_bucket.task1bucket.id
    key = "mm.jpg"    
	source = "cloudimage/mm.jpg"
    acl = "public-read"
}
//Creating a cloud front
resource "aws_cloudfront_distribution" "distribution" {
	depends_on = [aws_s3_bucket.task1bucket]
	origin 
	{
		domain_name = aws_s3_bucket.task1bucket.bucket_regional_domain_name
		origin_id   = "S3-task1bucketofashutoshtiwari-id"
		custom_origin_config
		{
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}
 	enabled = true
  	default_cache_behavior 
		{
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "S3-task1bucketofashutoshtiwari-id"
 		forwarded_values 
			{
			query_string = false
 			cookies 
				{
				forward = "none"
				}
			}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
		}
 	restrictions 
		{
		geo_restriction	
				{
 				restriction_type = "none"
				}
		}
 	viewer_certificate
		{
		cloudfront_default_certificate = true
		}
}