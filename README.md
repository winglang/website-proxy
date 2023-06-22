# Website Proxy

This is the Cloudfront reverse proxy for [winglang.io](https://winglang.io) (currently deployed as [winglang.ai](https://winglang.ai) and [docs1.winglang.ai](https://docs1.winglang.ai)) to unify the underlying targets:

- [Docsite](https://docsite-omega.vercel.app/) which is serving `docs` and `blog` content as a [Docusaurus](https://docusaurus.io/) app hosted on Vercel. The code can be found [here](https://github.com/winglang/docsite)
- [Homepage](https://winglang.webflow.io) - which is a [webflow](https://webflow.com/) site and serving landing pages including the main landing page

## Behaviors

- by default, all requests are routed to the `Homepage` (winglang.webflow.io)
- `/(docs|docs/*)` is routed to the `Docsite` (docsite-omega.vercel.app)
- `/(blog|blog/*)` is routed to the `Docsite` (docsite-omega.vercel.app)
- `/assets/*` is routed to the `Docsite` (docsite-omega.vercel.app)
- `/img/*` is routed to the `Docsite` (docsite-omega.vercel.app)

This means:

- The `Homepage` can essentially add or change any url path as desired, as long as it's not conflicting with the `Docsite`. There's no change in Cloudfront neccessary.
- If the `Docsite` want's to add or change root paths, a change in the corresponding Cloudfront behaviour is neccessary.

I've checked the Webflow url path structure, and it looks like that all assets are loaded from other domains. No relative assets seem to be referenced. If this would change at some point this would need to be addressed here as well, but it seems unlikely.

## Roadmap

- [x] Refactor the code a bit for better readability
- [x] Fix / and missing assets
- [x] Replace [forwardValues](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-forwardedvalues.html) with [policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/controlling-origin-requests.html) since `forwardValues` is deprecated
- [x] Provide correct redirect logic in redirect distribution
- [x] winglang.io needs to point to the distribution. Since all DNS should still be handled in dnsimple, there needs to be manual wiring of certificate and domain
- [x] Create new AWS account for deployment (using website)
- [x] OIDC setup in https://github.com/winglang/examples-baseline (needs to be renamed)
- [x] Github Action for deployment
- [ ] Is there some website monitoring in place somewhere (should be updated or created)?
- [ ] Use correct domain rather than the winglang.ai placeholder (in [./redirect.w](./redirect.w) and [./main.w](./main.w))
- [ ] Make sure to update [redirect handler](./redirect.handler.js) as well

Depending on if this repo should be open sourced or not, the dnsimple handling could either stay here and being handled automatically as it is right now or remove it after the intial deployment (if open sourcing). If the dnsimple tokens were leaked for some reason, this would be pretty bad. While it's possible in dnsimple to have "zone manager" users and limit them to one domain only, it's not possible to be more granular than that.

# Redirect (temporary)

A pure redirect Cloudfront distribution, redirecting:

- docs.winglang.io/blog/* -> winglang.io/blog
- docs.winglang.io/* -> winglang.io/docs

That's implemented via [Cloudfront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html) for simplicity reasons.

See [./redirect.w](./redirect.w) and [./redirect.handler.js](./redirect.handler.js) and the tests [./redirect.handler.test.js](./redirect.handler.test.js)

The test can be executed after the distribution is deployed. Can be simplified and inlined into Wing once https://github.com/winglang/wing/issues/1878 is there.

The entire redirect distribution can be dropped once the traffic goes away.