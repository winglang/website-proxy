bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;

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

let cert = new aws.acmCertificate.AcmCertificate(
  domainName: "docs.test.winglang.ai",
  validationMethod: "DNS"
);

let zone = new aws.dataAwsRoute53Zone.DataAwsRoute53Zone(
  name: "test.winglang.ai.",
  privateZone: false
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
    for dvo in ${cert.fqn}.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}");

let certValidation = new aws.acmCertificateValidation.AcmCertificateValidation(
  certificateArn: cert.arn
);

certValidation.addOverride("validation_record_fqdns", "\${[for record in ${record.fqn} : record.fqdn]}");

let disribution = new aws.cloudfrontDistribution.CloudfrontDistribution(
  enabled: true,
  isIpv6Enabled: true,

  viewerCertificate: aws.cloudfrontDistribution.CloudfrontDistributionViewerCertificate {
    acmCertificateArn: cert.arn,
    sslSupportMethod: "sni-only"
  },

  restrictions: aws.cloudfrontDistribution.CloudfrontDistributionRestrictions {
    geoRestriction: aws.cloudfrontDistribution.CloudfrontDistributionRestrictionsGeoRestriction {
      restrictionType: "none"
    }
  },

  origin: [{
    originId: "stub",
    domainName: "stub.winglang.ai",
  }],

  aliases: [
    "docs.test.winglang.ai",
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


let domain = new aws.route53Record.Route53Record(
  name: "docs.test.winglang.ai",
  type: "A",
  zoneId: zone.zoneId,
  alias: aws.route53Record.Route53RecordAlias {
    name: disribution.domainName,
    zoneId: disribution.hostedZoneId,
    evaluateTargetHealth: true
  }
) as "docs.winglang.ai";


// not working yet because of https://github.com/winglang/wing/issues/1878
// test "docs.test.winglang.ai" {
//   assert(domain.fqdn == "docs.test.winglang.ai");
// }
