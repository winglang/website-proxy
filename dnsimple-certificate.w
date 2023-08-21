bring cloud;
bring "@cdktf/provider-aws" as aws;
bring "@cdktf/provider-dnsimple" as dnsimple;

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
      lifecycle: {
        createBeforeDestroy: true
      }
    );

    // this gets ugly, but it's the only way to get the validation records
    // https://github.com/hashicorp/terraform-cdk/issues/2178
    let record = new dnsimple.zoneRecord.ZoneRecord(
      name: "replaced",
      type: "\${each.value.type}",
      value: "replaced",
      zoneName: zoneName,
      ttl: 60,
    );

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
    );

    certValidation.addOverride("validation_record_fqdns", "\${[for record in ${record.fqn} : record.qualified_name]}");
  }
}
