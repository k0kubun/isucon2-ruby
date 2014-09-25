# ISUCON2 answer

My answer for [ISUCON2](https://github.com/tagomoris/isucon2) written in Ruby.

## Preparation

This is built on isucon\_summer\_class\_2014 AMI in Tokyo Region.  
Before applying this repository, launch EC2 instance with it.

## Deploy

```bash
$ gem install itamae --pre
$ itamae ssh deploy.rb -h ec2-***.amazonaws.com -u isu-user -i ~/.ssh/id_rsa.isucon
```

## Benchmark

```bash
$ itamae ssh bench.rb -l debug -h ec2-***.amazonaws.com -u isu-user -i ~/.ssh/id_rsa.isucon
```
