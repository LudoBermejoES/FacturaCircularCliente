# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - banner [ref=e2]:
    - 'heading "Blocked hosts: web:3000" [level=1] [ref=e3]'
  - main [ref=e4]:
    - heading "To allow requests to these hosts, make sure they are valid hostnames (containing only numbers, letters, dashes and dots), then add the following to your environment configuration:" [level=2] [ref=e5]
    - generic [ref=e6]: config.hosts << "web:3000"
    - paragraph [ref=e7]:
      - text: "For more details view:"
      - link "the Host Authorization guide" [ref=e8] [cursor=pointer]:
        - /url: https://guides.rubyonrails.org/configuring.html#actiondispatch-hostauthorization
```