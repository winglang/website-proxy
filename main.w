bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;
// https://vercel.com/guides/can-i-use-a-proxy-on-top-of-my-vercel-deployment

struct Route53ValidatedCertificateProps {
  domainName: str;
  zone: aws.dataAwsRoute53Zone.DataAwsRoute53Zone;
}

class Route53ValidatedCertificate {
  resource: aws.acmCertificate.AcmCertificate;

  init(props: Route53ValidatedCertificateProps) {
    let domainName = props.domainName;
    let zone = props.zone;

    this.resource = new aws.acmCertificate.AcmCertificate(
      domainName: domainName,
      validationMethod: "DNS"
    );

    // this gets ugly, but it's the only way to get the validation records
    // https://github.com/hashicorp/terraform-cdk/issues/2178
    let record = new aws.route53Record.Route53Record(
      name: "\${each.value.name}",
      type: "\${each.value.type}",
      records: [
        "\${each.value.record}"
      ],
      zoneId: zone.zoneId,
      ttl: 60,
      allowOverwrite: true
    );

    record.addOverride("for_each", "\${{
        for dvo in ${this.resource.fqn}.domain_validation_options : dvo.domain_name => {
          name   = dvo.resource_record_name
          record = dvo.resource_record_value
          type   = dvo.resource_record_type
        }
      }
    }");

    let certValidation = new aws.acmCertificateValidation.AcmCertificateValidation(
      certificateArn: this.resource.arn
    );

    certValidation.addOverride("validation_record_fqdns", "\${[for record in ${record.fqn} : record.fqdn]}");
  }
}

struct ReverseProxyDistributionProps {
  cert: Route53ValidatedCertificate;
  aliases: Array<str>;
}

class ReverseProxyDistribution {
  resource: aws.cloudfrontDistribution.CloudfrontDistribution;
  policy: aws.cloudfrontCachePolicy.CloudfrontCachePolicy;

  init(props: ReverseProxyDistributionProps) {
    let cert = props.cert;
    let aliases = props.aliases;

    this.policy = new aws.cloudfrontCachePolicy.CloudfrontCachePolicy(
      defaultTtl: 60,
      maxTtl: 86400,
      minTtl: 0,
      name: "winglang-proxy-cache-policy",
      parametersInCacheKeyAndForwardedToOrigin: aws.cloudfrontCachePolicy.CloudfrontCachePolicyParametersInCacheKeyAndForwardedToOrigin {
        cookiesConfig: aws.cloudfrontCachePolicy.CloudfrontCachePolicyParametersInCacheKeyAndForwardedToOriginCookiesConfig {
          cookieBehavior: "all",
        },
        headersConfig: aws.cloudfrontCachePolicy.CloudfrontCachePolicyParametersInCacheKeyAndForwardedToOriginHeadersConfig {
          headerBehavior: "whitelist",
          headers: aws.cloudfrontCachePolicy.CloudfrontCachePolicyParametersInCacheKeyAndForwardedToOriginHeadersConfigHeaders {
            items: ["Accept-Datetime", "Accept-Encoding", "Accept-Language", "User-Agent", "Referer", "Origin", "X-Forwarded-Host"],
          },
        },
        queryStringsConfig: aws.cloudfrontCachePolicy.CloudfrontCachePolicyParametersInCacheKeyAndForwardedToOriginQueryStringsConfig {
          queryStringBehavior: "all",
        },
      }
    );

    this.resource = new aws.cloudfrontDistribution.CloudfrontDistribution(
      enabled: true,
      isIpv6Enabled: true,

      viewerCertificate: aws.cloudfrontDistribution.CloudfrontDistributionViewerCertificate {
        acmCertificateArn: cert.resource.arn,
        sslSupportMethod: "sni-only"
      },

      restrictions: aws.cloudfrontDistribution.CloudfrontDistributionRestrictions {
        geoRestriction: aws.cloudfrontDistribution.CloudfrontDistributionRestrictionsGeoRestriction {
          restrictionType: "none"
        }
      },

      origin: [{
        originId: "docs",
        domainName: "wing-docs-git-docs-base-path-test-monada.vercel.app",
      },
      {
        originId: "home",
        domainName: "winglang.webflow.io",
      }],

      aliases: aliases,

      defaultCacheBehavior: aws.cloudfrontDistribution.CloudfrontDistributionDefaultCacheBehavior {
        minTtl: 0,
        defaultTtl: 60,
        maxTtl: 86400,
        allowedMethods: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"],
        cachedMethods: ["GET", "HEAD"],
        targetOriginId: "home",
        viewerProtocolPolicy: "redirect-to-https",
        cachePolicyId: this.policy.id,
      },

      orderedCacheBehavior: [
        this.docsBehavior("/docs"),
        this.docsBehavior("/blog"),
        this.docsBehavior("/docs/*"),
        this.docsBehavior("/blog/*"),
        this.docsBehavior("/assets/*"),
        this.docsBehavior("/img/*"),
      ],
    );

    this.patchOriginConfig();
 }

  domainName(): str {
    return this.resource.domainName;
  }

  hostedZoneId(): str {
    return this.resource.hostedZoneId;
  }

  docsBehavior(pathPattern: str): aws.cloudfrontDistribution.CloudfrontDistributionOrderedCacheBehavior {
    return aws.cloudfrontDistribution.CloudfrontDistributionOrderedCacheBehavior {
      pathPattern: pathPattern,
      minTtl: 0,
      defaultTtl: 60,
      maxTtl: 86400,
      allowedMethods: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"],
      cachedMethods: ["GET", "HEAD"],
      targetOriginId: "docs",
      viewerProtocolPolicy: "redirect-to-https",
      cachePolicyId: this.policy.id,
    };
  }

  // this should be part of the origin definition above, but there's a bug https://github.com/winglang/wing/issues/2597
  patchOriginConfig() {
    this.resource.addOverride("origin.0.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });

    this.resource.addOverride("origin.1.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });
  }
}

let domainName = "test.winglang.ai";

let zone = new aws.dataAwsRoute53Zone.DataAwsRoute53Zone(
  name: "${domainName}.",
  privateZone: false
);

let cert = new Route53ValidatedCertificate(
  domainName: domainName,
  zone: zone
);

let disribution = new ReverseProxyDistribution(
  aliases: [domainName],
  cert: cert
);

let domain = new aws.route53Record.Route53Record(
  name: domainName,
  type: "A",
  zoneId: zone.zoneId,
  alias: aws.route53Record.Route53RecordAlias {
    name: disribution.domainName(),
    zoneId: disribution.hostedZoneId(),
    evaluateTargetHealth: true
  }
);