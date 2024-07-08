
/**
 * copied from https://github.com/aws-samples/amazon-cloudfront-functions/issues/11#issuecomment-1010898761
 * Patches lack of
 * https://developer.mozilla.org/en-US/docs/Web/API/Location/search in event.
 * Inspired by
 * https://github.com/aws-samples/amazon-cloudfront-functions/issues/11.
 * @param obj The weird format exposed by CloudFront
 * https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-event-structure.html#functions-event-structure-query-header-cookie
 * @returns {string} Tries to return the same as
 * https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams/toString
 */
function getURLSearchParamsString(obj) {
  var str = [];
  for (var param in obj) {
    if (obj[param].multiValue) {
      str.push(
        obj[param].multiValue.map((item) => param + "=" + item.value).join("&")
      );
    } else if (obj[param].value === "") {
      str.push(param);
    } else {
      str.push(param + "=" + obj[param].value);
    }
  }
  return str.join("&");
}

function handler(event) {
    var request = event.request;
    var newurl;

    var host = request.headers.host.value;

    if (host === "docs.winglang.io") {
      // redirect spacial paths in our docs. f.e: Check if the URI starts with '/blog'. If so, redirect to "https://docs.winglang.io/blog".
      if(request.uri.startsWith('/blog') || request.uri.startsWith('/contributing') || request.uri.startsWith("/terms-and-policies") || request.uri.startsWith("/api")) {
          newurl = `https://www.winglang.io${request.uri}`;
      } else {
          newurl = `https://www.winglang.io/docs${request.uri}`;
      }
    } else if (host === "play.winglang.io") {
      if(request.uri.startsWith('/play')) {
        newurl = `https://www.winglang.io${request.uri}`;
      } else {
          newurl = `https://www.winglang.io/play${request.uri}`;
      }
    } else if (host === "learn.winglang.io") {
      if (request.uri.startsWith('/learn')) {
        newurl = `https://www.winglang.io${request.uri}`;
      } else {
        newurl = `https://www.winglang.io/learn${request.uri}`;
      }
    } else {
      throw new Error("Unknown host: " + host);
    }

    // If there are querystring parameters, add them to the newurl.
    if (Object.keys(request.querystring).length) {
      newurl += '?' + getURLSearchParamsString(request.querystring);
    }

    var response = {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers: { "location": { "value": newurl } }
    }

    return response;
}