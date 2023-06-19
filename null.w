bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-null" as null;

let one = new null.resource.Resource(
  triggers: {
    foo: "bar"
  }
);

let two = new null.resource.Resource(
  triggers: {
    foo: "bar"
  }
  dependsOn: [one]
);
