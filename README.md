# route53-dynamic-dns-with-lambda
### A Dynamic DNS system built with API Gateway, Lambda &amp; Route 53.  

*This repository originally supplemented the blog post: [Building a Serverless Dynamic DNS System with AWS](https://medium.com/aws-activate-startup-blog/building-a-serverless-dynamic-dns-system-with-aws-a32256f0a1d8)  
Code and instructions for the version described in the blog can be found in the [v1](./v1/)  folder of this repository.*   

The project implements a serverless dynamic DNS system using AWS Lambda, Amazon API Gateway, Amazon Route 53 and Amazon DynamoDB.   
A bash reference client *route53-ddns-client.sh* is included, but the api calls for the system can be easily implemented in other languages.  
The benefits and overall architecture of the system described in [Building a Serverless Dynamic DNS System with AWS](https://aws.amazon.com/blogs/startups/building-a-serverless-dynamic-dns-system-with-aws/) are still accurate.   
