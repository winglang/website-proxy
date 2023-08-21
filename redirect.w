bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;
bring "@cdktf/provider-dnsimple" as dnsimple;
bring "./dnsimple-certificate.w" as dnsimpleCertificate;
bring "./cloudfront-function.w" as cfnFn;
bring "./smoke-test.w" as smokeTest;
bring http;

new dnsimple.provider.DnsimpleProvider();

let zoneName = "winglang.io";
let docsSubDomain = "docs";
let learnSubDomain = "learn";
let playSubDomain = "play";

let docsHandler = new cfnFn.CloudfrontFunction("docs") as "docs.CloudfrontFunction";
let learnHandler = new cfnFn.CloudfrontFunction("learn") as "learn.CloudfrontFunction";
let playHandler = new cfnFn.CloudfrontFunction("play") as "play.CloudfrontFunction";

// creates distribution with cert and cloudfront function
let createDistribution = (subDomain: str, zoneName: str, handler: aws.cloudfrontFunction.CloudfrontFunction): aws.cloudfrontDistribution.CloudfrontDistribution => {
  let cert = new dnsimpleCertificate.DnsimpleValidatedCertificate(
    domainName: "${subDomain}.${zoneName}",
    zoneName: zoneName
  ) as "${subDomain}.DnsimpleValidatedCertificate";

  let distribution = new aws.cloudfrontDistribution.CloudfrontDistribution(
    enabled: true,
    isIpv6Enabled: true,

    viewerCertificate: {
      acmCertificateArn: cert.resource.arn,
      sslSupportMethod: "sni-only"
    },

    restrictions: {
      geoRestriction: {
        restrictionType: "none"
      }
    },

    origin: [{
      originId: "stub",
      domainName: "stub.${zoneName}",
      customOriginConfig: {
        httpPort: 80,
        httpsPort: 443,
        originProtocolPolicy: "https-only",
        originSslProtocols: ["SSLv3", "TLSv1.1", "TLSv1.2"]
      }
    }],

    aliases: [
      "${subDomain}.${zoneName}",
    ],

    defaultCacheBehavior: {
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
      forwardedValues: {
        cookies: {
          forward: "all"
        },
        headers: ["Accept-Datetime", "Accept-Encoding", "Accept-Language", "User-Agent", "Referer", "Origin", "X-Forwarded-Host"],
        queryString: true
      }
    },
  ) as "${subDomain}.aws.cloudfrontDistribution.CloudfrontDistribution";

  return distribution;
};

// docs subdomain
let docsDistribution = createDistribution(docsSubDomain, zoneName, docsHandler.resource);
let docsRecord = new dnsimple.zoneRecord.ZoneRecord(
  name: docsSubDomain,
  type: "CNAME",
  value: docsDistribution.domainName,
  zoneName: zoneName,
  ttl: 60
) as "docs.dnsimple.zoneRecord.ZoneRecord";

// learn subdomain
let learnDistribution = createDistribution(learnSubDomain, zoneName, learnHandler.resource);
let learnRecord = new dnsimple.zoneRecord.ZoneRecord(
  name: learnSubDomain,
  type: "CNAME",
  value: learnDistribution.domainName,
  zoneName: zoneName,
  ttl: 60
) as "learn.dnsimple.zoneRecord.ZoneRecord";

// play subdomain
let playDistribution = createDistribution(playSubDomain, zoneName, playHandler.resource);
let playRecord = new dnsimple.zoneRecord.ZoneRecord(
  name: playSubDomain,
  type: "CNAME",
  value: playDistribution.domainName,
  zoneName: zoneName,
  ttl: 60
) as "play.dnsimple.zoneRecord.ZoneRecord";

new smokeTest.ExpectRedirect(docsRecord, {
  from: "/",
  to: "https://www.winglang.io/docs/",
}) as "smoke.docs.one";

new smokeTest.ExpectRedirect(docsRecord, {
  from: "/?bar=baz",
  to: "https://www.winglang.io/docs/?bar=baz",
}) as "smoke.docs.two";

new smokeTest.ExpectRedirect(learnRecord, {
  from: "/",
  to: "https://www.winglang.io/learn/",
}) as "smoke.learn.one";

new smokeTest.ExpectRedirect(learnRecord, {
  from: "/?bar=baz",
  to: "https://www.winglang.io/learn/?bar=baz",
}) as "smoke.learn.two";

new smokeTest.ExpectRedirect(playRecord, {
  from: "/",
  to: "https://www.winglang.io/play/",
}) as "smoke.play.one";

new smokeTest.ExpectRedirect(playRecord, {
  from: "/?bar=baz",
  to: "https://www.winglang.io/play/?bar=baz",
}) as "smoke.play.two";
