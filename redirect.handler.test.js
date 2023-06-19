import { TestFunctionCommand, CloudFrontClient, GetFunctionCommand } from '@aws-sdk/client-cloudfront';
import { describe, expect, test, beforeAll } from 'vitest'

const client = new CloudFrontClient({});

const getFunction = async () => {
  const command = new GetFunctionCommand({
    Name: 'redirect',
  })

  const result = await client.send(command)
  return result
}

describe("full integration test", () => {
  describe("root path", () => {
    let event = Buffer.from(JSON.stringify({
      "version": "1.0",
      "context": {
          "eventType": "viewer-request"
      },
      "viewer": {
          "ip": "198.51.100.11"
      },
      "request": {
          "method": "GET",
          "uri": "/",
          "headers": {
            "host": {"value": "docs.winglang.io"}
          }
      }
    }));
    let result;

    beforeAll(async () => {
      const fn = await getFunction('redirect')
      const command = new TestFunctionCommand({
        Name: 'redirect',
        IfMatch: fn.ETag,
        EventObject: event
      })

      result = await client.send(command)
    })

    test("responds with 301", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it does not utilise more than 80% of the maximum processing time", async () => {
      expect(Number(result.TestResult?.ComputeUtilization)).toBeLessThan(80)
    });

    test("it redirectst to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://winglang.ai/docs/');
    });
  });

  describe("nested path", () => {
    let event = Buffer.from(JSON.stringify({
        "version": "1.0",
        "context": {
            "eventType": "viewer-request"
        },
        "viewer": {
            "ip": "198.51.100.11"
        },
        "request": {
            "method": "GET",
            "uri": "/a-nested-path",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const fn = await getFunction('redirect')
      const command = new TestFunctionCommand({
        Name: 'redirect',
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it does not utilise more than 80% of the maximum processing time", async () => {
      expect(Number(result.TestResult?.ComputeUtilization)).toBeLessThan(80)
    });

    test("it redirectst to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://winglang.ai/docs/a-nested-path');
    });
  });


  describe("a blog path", () => {
    let event = Buffer.from(JSON.stringify({
        "version": "1.0",
        "context": {
            "eventType": "viewer-request"
        },
        "viewer": {
            "ip": "198.51.100.11"
        },
        "request": {
            "method": "GET",
            "uri": "/blog/12/93/a-blog-post",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const fn = await getFunction('redirect')
      const command = new TestFunctionCommand({
        Name: 'redirect',
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it does not utilise more than 80% of the maximum processing time", async () => {
      expect(Number(result.TestResult?.ComputeUtilization)).toBeLessThan(80)
    });

    test("it redirectst to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://winglang.ai/blog/12/93/a-blog-post');
    });
  });

  describe("a path with query strings", () => {
    let event = Buffer.from(JSON.stringify({
        "version": "1.0",
        "context": {
            "eventType": "viewer-request"
        },
        "viewer": {
            "ip": "198.51.100.11"
        },
        "request": {
            "method": "GET",
            "uri": "/a-doc-page?foo=bar&baz=qux",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const fn = await getFunction('redirect')
      const command = new TestFunctionCommand({
        Name: 'redirect',
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it does not utilise more than 80% of the maximum processing time", async () => {
      expect(Number(result.TestResult?.ComputeUtilization)).toBeLessThan(80)
    });

    test("it redirectst to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://winglang.ai/docs/a-doc-page?foo=bar&baz=qux');
    });
  });
});
