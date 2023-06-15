# Website Proxy

This is the Cloudfront reverse proxy for [winglang.io](https://winglang.io) to unify the underlying targets:

- [Docsite](https://docsite-omega.vercel.app/) which is serving `docs` and `blog` content as a [Docusaurus](https://docusaurus.io/) app hosted on Vercel. The code can be found [here](https://github.com/winglang/docsite)
- [Homepage](https://winglang.webflow.io) - which is a [webflow](https://webflow.com/) site and serving landing pages including the main landing page

## Behaviors

- by default, all requests are routed to the `Homepage` (winglang.webflow.io)
- `/docs` is routed to the `Docsite` (https://docsite-omega.vercel.app/)
- `/blog` is routed to the `Docsite` (https://docsite-omega.vercel.app/)
- `/assets` is routed to the `Docsite` (https://docsite-omega.vercel.app/)

This means:

- The `Homepage` can essentially add or change any url path as desired, as long as it's not conflicting with the `Docsite`. There's no change in Cloudfront neccessary.
- If the `Docsite` want's to add or change root paths, a change in the corresponding Cloudfront behaviour is neccessary.

I've checked the Webflow url path structure, and it looks like that all assets are loaded from other domains. No relative assets seem to be referenced. If this would change at some point this would need to be addressed here as well, but it seems unlikely.

## Roadmap

- [ ] Refactor the code a bit for better readability
- [ ] Replace [forwardValues](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-forwardedvalues.html) with [policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/controlling-origin-requests.html) since `forwardValues` is deprecated
- [ ] Create new AWS account for deployment
- [ ] OIDC setup in https://github.com/winglang/examples-baseline (needs to be renamed)
- [ ] Github Action for deployment
- [ ] Is there some website monitoring in place somewhere (should be updated or created)?
- [ ] Use correct domain rather than the winglang.ai placeholder

# Redirect (temporary)

A pure redirect Cloudfront distribution, redirecting:

- docs.winglang.io/blog/* -> winglang.io/blog
- docs.winglang.io/* -> winglang.io/docs

That's implemented via [Cloudfront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html) for simplicity reasons.

See [./redirect.w](./redirect.w) and [./redirect.handler.js](./redirect.handler.js)

The entire redirect distribution can be dropped once the traffic goes away.