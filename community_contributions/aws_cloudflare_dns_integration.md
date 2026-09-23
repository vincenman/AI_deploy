For the people not use route53 like me but Cloudflare as domain provider, CloudFront has a convenient 3-step flow for this:


### 1. CloudFront -> Distributions -> Add domain

Open your distribution, choose **Add domain** and enter the domain you want to use, for example:

```text
www.your-domain.com
```

CloudFront then walks you through:

```text
Step 1: Configure domains
Step 2: Get TLS certificate
Step 3: Review changes
```

### 2. Configure domains

Add your custom domain:

```text
www.your-domain.com
```

CloudFront will associate this hostname with the distribution.

### 3. Get TLS certificate

Choose to create or use an ACM certificate.

For CloudFront, the certificate must be in:

```text
us-east-1 (N. Virginia)
```

Even if your AWS application itself is running in a region like `us-west-1`.

CloudFront will give you a DNS validation CNAME record. Go to:

```
Cloudflare -> DNS -> Records
```

and add that CNAME as **DNS only**, not proxied.

After adding the validation record in Cloudflare, ACM may remain on "Pending validation" for a minute or two. That's normal. Just wait for it to become:

```text
Issued
```

### 4. Review changes

Once the certificate is validated, review the configuration and apply the changes to the CloudFront distribution.

### 5. Point Cloudflare to CloudFront

In Cloudflare DNS, create:

```text
Type: CNAME
Name: www
Target: xxx.cloudfront.net
Proxy: DNS only
```

For the root domain:

```text
Type: CNAME
Name: @
Target: xxx.cloudfront.net
Proxy: DNS only
```

### 6. Enable HTTPS

In:

```
CloudFront -> Distribution -> Behaviors -> Edit
```

set Viewer protocol policy to:

```text
HTTPS only
```

or, for a normal public website:

```text
Redirect HTTP to HTTPS
```

Final flow:

```text
www.your-domain.com
      |
      v
Cloudflare DNS
      |
      v
CloudFront + ACM TLS
      |
      v
AWS origin
```

