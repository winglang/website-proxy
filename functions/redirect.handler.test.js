import { TestFunctionCommand, CloudFrontClient, CreateFunctionCommand, DeleteFunctionCommand } from '@aws-sdk/client-cloudfront';
import { describe, expect, test, beforeAll, afterAll } from 'vitest'
import fs from 'fs'
import path from 'path'

const client = new CloudFrontClient({});

const deleteFunction = async (fn) => {
  const command = new DeleteFunctionCommand({
    Name: fn.FunctionSummary.Name,
    IfMatch: fn.ETag
  })
  await client.send(command)
}

const createFunction = async (name) => {
  const code = fs.readFileSync(path.join(__dirname, `./${name}.js`))
  const command = new CreateFunctionCommand({
    Name: `test-redirect-handler-${name}`,
    FunctionCode: code,
    FunctionConfig: {
      Comment: `test-redirect-handler-${name}`,
      Runtime: 'cloudfront-js-1.0'
    }
  })

  const result = await client.send(command)
  return result
}

describe("docs full integration test", () => {
  let fn;

  beforeAll(async () => {
    fn = await createFunction('redirect')
  })

  afterAll(async () => {
    await deleteFunction(fn)
  })

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
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/docs/');
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
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/docs/a-nested-path');
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
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/blog/12/93/a-blog-post');
    });
  });

  describe("a api path", () => {
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
            "uri": "/api/test",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/api/test');
    });
  });

  describe("a contributing path", () => {
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
            "uri": "/contributing/foo",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/contributing/foo');
    });
  });

   describe("a terms-and-policies path", () => {
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
            "uri": "/terms-and-policies",
            "headers": {
              "host": {"value": "docs.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
        IfMatch: fn.ETag,
        EventObject: event,
      })

      result = await client.send(command)
    })

    test("responds with 301 status code", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      expect(functionOutput.response.statusCode).toBe(301)
    });

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/terms-and-policies');
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
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/docs/a-doc-page?foo=bar&baz=qux');
    });
  });
});


// Path: functions/learn.js

describe("learn full integration test", () => {
  let fn;

  beforeAll(async () => {
    fn = await createFunction('redirect')
  })

  afterAll(async () => {
    await deleteFunction(fn)
  })

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
            "host": {"value": "learn.winglang.io"}
          }
      }
    }));
    let result;

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/learn/');
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
              "host": {"value": "learn.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/learn/a-nested-path');
    });
  });


  describe("a learn path", () => {
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
            "uri": "/learn",
            "headers": {
              "host": {"value": "learn.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/learn');
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
              "host": {"value": "learn.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/learn/a-doc-page?foo=bar&baz=qux');
    });
  });
});




describe("play full integration test", () => {
  let fn;

  beforeAll(async () => {
    fn = await createFunction('redirect')
  })

  afterAll(async () => {
    await deleteFunction(fn)
  })

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
            "host": {"value": "play.winglang.io"}
          }
      }
    }));
    let result;

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/play/');
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
              "host": {"value": "play.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/play/a-nested-path');
    });
  });


  describe("a play path", () => {
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
            "uri": "/play",
            "headers": {
              "host": {"value": "play.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/play');
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
              "host": {"value": "play.winglang.io"}
            }
        }
    }))
    let result

    beforeAll(async () => {
      const command = new TestFunctionCommand({
        Name: fn.FunctionSummary.Name,
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

    test("it redirects to new url structure", async () => {
      const functionOutput = JSON.parse(result.TestResult?.FunctionOutput)
      const locationHeader = functionOutput.response.headers.location.value
      expect(locationHeader).toEqual('https://www.winglang.io/play/a-doc-page?foo=bar&baz=qux');
    });
  });
});
