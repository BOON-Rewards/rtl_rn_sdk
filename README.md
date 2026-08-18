# RTL SDK for React native

See the public RTL developer documentation:

https://crowdplay.gitbook.io/rtl-developer-documentation

## Configuration

Initialize the SDK with the complete base URL provided for the client. The SDK
does not select an environment or construct a host name.

```tsx
await RTL.initialize({
  baseUrl: 'https://client-provided-url.example',
  urlScheme: 'your-app-scheme',
});
```

## Deep linking

The SDK sends the host app's `urlScheme` to RTL during login as the `appScheme`
query parameter on `/auth/token-forward`. When RTL needs to open the wrapped app
for a specific destination, the consumer app receives a URL in this shape:

```text
<urlScheme>://rtlsdk?rtlEventId=<event-id>&rtlRedirectUrl=<encoded-url>
```

Consumer apps should:

1. Register the same URL scheme passed to `RTL.initialize`.
2. Forward incoming app URLs to React Native `Linking` on iOS.
3. Add an Android `VIEW` intent filter with `singleTask` launch mode.
4. Parse only URLs whose scheme matches `urlScheme` and whose host is `rtlsdk`.
5. Call `RTL.presentExperience({ rtlEventId, rtlRedirectUrl })`.

For cold-start links, wait until `RTL.initialize(...)` has resolved and
`<RTLView />` has mounted before calling `presentExperience`; otherwise the
native SDK may not have created the underlying web view yet.
