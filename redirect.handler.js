function handler(event) {
    var request = event.request;
    var newurl;

    // Check if the URI starts with '/blog'. If so, redirect to "https://docs.winglang.io/blog".
    if(request.uri.startsWith('/blog')) {
        newurl = `https://winglang.io${request.uri}`;
    } else {
        newurl = `https://winglang.io/docs${request.uri}`;
    }

    // If there are querystring parameters, add them to the newurl.
    if (request.querystring && request.querystring.length > 0) {
        var queryParams = [];
        for (var key in request.querystring) {
            if (request.querystring.hasOwnProperty(key)) {
                queryParams.push(`${encodeURIComponent(key)}=${encodeURIComponent(request.querystring[key].value)}`);
            }
        }
        newurl += '?' + queryParams.join('&');
    }

    var response = {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers: { "location": { "value": newurl } }
    }

    return response;
}