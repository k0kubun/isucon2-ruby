# ISUCON2 answer

My answer for [ISUCON2](https://github.com/tagomoris/isucon2) written in Ruby.

## Preparation

This is built on isucon\_summer\_class\_2014 AMI in Tokyo Region.  
Before applying this repository, launch EC2 instance with it.  
  
Edit init.rb to change public key, then execute:

```bash
$ itamae ssh init.rb -h ec2-***.amazonaws.com -u ec2-user -i isucon.pem
```

## Deploy

```bash
$ gem install itamae --pre
$ itamae ssh deploy.rb -h ec2-***.amazonaws.com -u isu-user -i id_rsa.isucon
```

Then you'll see ISUCON2 application on port 80.  
  
And benchmark application will be available on port 5001.  
You can login with user: team1, password: xxx.
