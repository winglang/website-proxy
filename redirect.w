bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;
bring "@cdktf/provider-dnsimple" as dnsimple;

new dnsimple.provider.DnsimpleProvider();

let zoneName = "winglang.ai";
let subDomain = "docs";

let handlerFile = new cdktf.TerraformAsset(
  path: "./redirect.handler.js",
  type: cdktf.AssetType.FILE
);

let handler = new aws.cloudfrontFunction.CloudfrontFunction(
  name: "redirect",
  comment: "Redirects to the docs subdomain",
  code: cdktf.Fn.file(handlerFile.path),
  runtime: "cloudfront-js-1.0",
  publish: true
);

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
    );

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
    );

    // tried name: cdktf.Fn.replace("each.value.name", ".winglang.ai.", ""), but that didn't work
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
    );

    certValidation.addOverride("validation_record_fqdns", "\${[for record in ${record.fqn} : record.qualified_name]}");
  }
}

let cert = new DnsimpleValidatedCertificate(
  domainName: "${subDomain}.${zoneName}",
  zoneName: zoneName
);

let disribution = new aws.cloudfrontDistribution.CloudfrontDistribution(
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
    originId: "stub",
    domainName: "stub.${zoneName}",
  }],

  aliases: [
    "${subDomain}.${zoneName}",
  ],

  defaultCacheBehavior: aws.cloudfrontDistribution.CloudfrontDistributionDefaultCacheBehavior {
    minTtl: 0,
    defaultTtl: 60,
    maxTtl: 86400,
    allowedMethods: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"],
    cachedMethods: ["GET", "HEAD"],
    targetOriginId: "stub",
    viewerProtocolPolicy: "redirect-to-https",
    functionAssociation: [{
      eventType: "viewer-request",
      functionArn: handler.arn
    }],
    forwardedValues: aws.cloudfrontDistribution.CloudfrontDistributionDefaultCacheBehaviorForwardedValues {
      cookies: aws.cloudfrontDistribution.CloudfrontDistributionDefaultCacheBehaviorForwardedValuesCookies {
        forward: "all"
      },
      headers: ["Accept-Datetime", "Accept-Encoding", "Accept-Language", "User-Agent", "Referer", "Origin", "X-Forwarded-Host"],
      queryString: true
    }
  },
);

disribution.addOverride("origin.0.custom_origin_config", {
  http_port: 80,
  https_port: 443,
  origin_protocol_policy: cdktf.Token.asNumber("https-only"), // why, where's the type info coming from?
  origin_ssl_protocols: cdktf.Token.asNumber(["SSLv3", "TLSv1.2", "TLSv1.1"]) // why?
});

new dnsimple.zoneRecord.ZoneRecord(
  name: subDomain,
  type: "CNAME",
  value: disribution.domainName,
  zoneName: zoneName,
  ttl: 60
);