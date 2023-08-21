bring cloud;
bring "cdktf" as cdktf;
bring "@cdktf/provider-aws" as aws;

class CloudfrontFunction {
  resource: aws.cloudfrontFunction.CloudfrontFunction;

  init(name: str) {
    let file = new cdktf.TerraformAsset(
      // relative to the project root
      path: "./functions/redirect.js",
      type: cdktf.AssetType.FILE
    );

    this.resource = new aws.cloudfrontFunction.CloudfrontFunction(
      name: "redirect-handler-${name}",
      comment: "Redirects to the ${name} subdomain",
      code: cdktf.Fn.file(file.path),
      runtime: "cloudfront-js-1.0",
      publish: true,
      lifecycle: {
        createBeforeDestroy: true,
      }
    );
  }
}
