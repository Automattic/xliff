# Vendored XLIFF 1.2 schemas

The official OASIS XLIFF 1.2 XSDs, vendored so `spec/xliff/bundle_spec.rb`'s "XLIFF 1.2 schema conformance"
examples validate serialized output offline (CI must not depend on the network).

| File | Source |
| --- | --- |
| `xliff-core-1.2-strict.xsd` | <http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd> |
| `xliff-core-1.2-transitional.xsd` | <http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-transitional.xsd> |
| `xml.xsd` | <http://www.w3.org/2001/xml.xsd> (imported by both core schemas for `xml:lang`/`xml:space`) |

**The only change from upstream:** in both core schemas the `xml.xsd` import was repointed from the network
URL to the vendored copy, so validation resolves it locally:

```diff
-<xsd:import namespace="http://www.w3.org/XML/1998/namespace" schemaLocation="http://www.w3.org/2001/xml.xsd"/>
+<xsd:import namespace="http://www.w3.org/XML/1998/namespace" schemaLocation="xml.xsd"/>
```
