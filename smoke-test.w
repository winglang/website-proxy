bring cloud;
bring http;
bring "@cdktf/provider-dnsimple" as dnsimple;

struct ExpectRedirectProps {
  from: str;
  to: str;
}

class ExpectRedirect {
  init(resource: dnsimple.zoneRecord.ZoneRecord, props: ExpectRedirectProps) {
    let path = props.from;
    let location = props.to;
    let domain = "${resource.name}.${resource.zoneName}";
    new cloud.OnDeploy(inflight() => {
      let url = "https://${domain}${path}";
      // this follows the redirect automatically
      let result = http.get(url);
      try {
        assert(result.status == 200);
      } catch e {
        throw("Expected ${url} to redirect to ${location} with final status of 200, but got ${result.url} with status ${result.status} - ${e}");
      }

      try {
        assert(result.url == location);
      } catch e {
        throw("Expected ${url} to redirect to ${location}, but got ${result.url} - ${e}");
      }
    }, {
      executeAfter: [resource],
      timeout: 10s,
    });
  }
}
