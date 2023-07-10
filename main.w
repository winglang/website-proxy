bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;
bring "@cdktf/provider-dnsimple" as dnsimple;
bring "@cdktf/provider-http" as httpProvider;

new httpProvider.provider.HttpProvider();
new dnsimple.provider.DnsimpleProvider();

let check = new httpProvider.dataHttp.DataHttp(
  url: "https://www.winglang.io",
  lifecycle: cdktf.TerraformResourceLifecycle {
    postcondition: [cdktf.Postcondition {
      condition: "\${contains([200], self.status_code)}",
      errorMessage: "Expected status code 200"
    }]
  }
) as "winglang.httpProvider.dataHttp.DataHttp";

let zoneName = "winglang.io";
let subDomain = "www";

let defaultOrigin = "webflow.winglang.io";
let docsOrigin = "docsite-omega.vercel.app";
let learnOrigin = "playground-tour.vercel.app";
// temp for testing
let playOrigin = "playground-git-play-single-domain-monada.vercel.app";

struct DnsimpleValidatedCertificateProps {
  domainName: str;
  zoneName: str;
}

class DnsimpleValidatedCertificate {
  resource: aws.acmCertificate.AcmCertificate;

  init(props: DnsimpleValidatedCertificateProps) {
    let domainName = props.domainName;
    let zoneName = props.zoneName;

    this.resource = new aws.acmCertificate.AcmCertificate(
      domainName: domainName,
      validationMethod: "DNS",
    ) as "${domainName}.aws.acmCertificate.AcmCertificate";

    // waits for https://github.com/winglang/wing/issues/2597
    this.resource.addOverride("lifecycle", {
      create_before_destroy: true
    });

    // this gets ugly, but it's the only way to get the validation records
    // https://github.com/hashicorp/terraform-cdk/issues/2178
    let record = new dnsimple.zoneRecord.ZoneRecord(
      name: "replaced",
      type: "\${each.value.type}",
      value: "replaced",
      zoneName: zoneName,
      ttl: 60,
    ) as "${zoneName}.dnsimple.zoneRecord.ZoneRecord";

    // tried name: cdktf.Fn.replace("each.value.name", ".winglang.io.", ""), but that didn't work
    // since "each.value.name" isn't interpolated properly
    record.addOverride("name", "\${replace(each.value.name, \".${zoneName}.\", \"\")}");
    record.addOverride("value", "\${replace(each.value.record, \"acm-validations.aws.\", \"acm-validations.aws\")}");
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
    )as "${domainName}.aws.acmCertificateValidation.AcmCertificateValidation";

    certValidation.addOverride("validation_record_fqdns", "\${[for record in ${record.fqn} : record.qualified_name]}");
  }
}

struct ReverseProxyDistributionProps {
  cert: DnsimpleValidatedCertificate;
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
      name: "winglang-io-proxy-cache-policy",
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
    ) as "winglang.io.aws.cloudfrontCachePolicy.CloudfrontCachePolicy";

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
        domainName: docsOrigin,
      },
      {
        originId: "learn",
        domainName: learnOrigin,
      },
      {
        originId: "play",
        domainName: playOrigin,
    },
      {
        originId: "home",
        domainName: defaultOrigin,
      }],

      aliases: aliases,

      defaultCacheBehavior: aws.cloudfrontDistribution.CloudfrontDistributionDefaultCacheBehavior {
        allowedMethods: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"],
        cachedMethods: ["GET", "HEAD"],
        targetOriginId: "home",
        viewerProtocolPolicy: "redirect-to-https",
        cachePolicyId: this.policy.id,
      },

      orderedCacheBehavior: [
        // docs site
        this.targetBehavior("docs","/docs"),
        this.targetBehavior("docs","/blog"),
        this.targetBehavior("docs","/docs/*"),
        this.targetBehavior("docs","/blog/*"),
        this.targetBehavior("docs","/assets/*"),
        this.targetBehavior("docs","/img/*"),
        this.targetBehavior("docs","/contributing"),
        this.targetBehavior("docs","/contributing/*"),
        this.targetBehavior("docs","/terms-and-policies"),
        this.targetBehavior("docs","/terms-and-policies/*"),
        // learn site
        this.targetBehavior("learn","/learn/*"),
        this.targetBehavior("learn","/learn"),
        // play site
        this.targetBehavior("play","/play/*"),
        this.targetBehavior("play","/play"),
      ],
    ) as "winglang.io.aws.cloudfrontDistribution.CloudfrontDistribution";

    this.patchOriginConfig();
 }

  domainName(): str {
    return this.resource.domainName;
  }

  hostedZoneId(): str {
    return this.resource.hostedZoneId;
  }

  targetBehavior(targetOriginId: str, pathPattern: str): aws.cloudfrontDistribution.CloudfrontDistributionOrderedCacheBehavior {
    return aws.cloudfrontDistribution.CloudfrontDistributionOrderedCacheBehavior {
      pathPattern: pathPattern,
      allowedMethods: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"],
      cachedMethods: ["GET", "HEAD"],
      targetOriginId: targetOriginId,
      viewerProtocolPolicy: "redirect-to-https",
      cachePolicyId: this.policy.id,
    };
  }

  // this should be part of the origin definition above, but there's a bug https://github.com/winglang/wing/issues/2597
  patchOriginConfig() {
    // docs
    this.resource.addOverride("origin.0.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });
    // learn
    this.resource.addOverride("origin.1.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });
    // play
    this.resource.addOverride("origin.2.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });
    // home
    this.resource.addOverride("origin.3.custom_origin_config", {
      http_port: 80,
      https_port: 443,
      origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
      origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
    });
  }
}

let cert = new DnsimpleValidatedCertificate(
  zoneName: zoneName,
  domainName: "${subDomain}.${zoneName}"
) as "${zoneName}.DnsimpleValidatedCertificate";

let disribution = new ReverseProxyDistribution(
  aliases: ["${subDomain}.${zoneName}"],
  cert: cert
) as "${zoneName}.ReverseProxyDistribution";

let record = new dnsimple.zoneRecord.ZoneRecord(
  name: subDomain,
  type: "CNAME",
  value: disribution.domainName(),
  zoneName: zoneName,
  ttl: 60,
) as "${zoneName}.dnsimple.zoneRecord.ZoneRecord";

// see https://github.com/winglang/wing/issues/2976
check.addOverride("depends_on", [
  "${record.terraformResourceType}.${record.friendlyUniqueId}",
  "${disribution.resource.terraformResourceType}.${disribution.resource.friendlyUniqueId}",
]);