# Tailscale subnet router on Render (DocSpring)

Gives the DocSpring tailnet access to Render's private network, mainly the
ClickHouse database behind Plausible (pa.docspring.com). Forked from
[render-examples/tailscale](https://github.com/render-examples/tailscale).

- Service settings (env vars, Tailscale version, advertised route) are managed
  by Terraform in `convox_racks_terraform/render`.
- It logs in with a Tailscale OAuth client (`TAILSCALE_AUTHKEY`, from
  `convox_racks_terraform/tailscale`) as `tag:render-subnet-router`, and its
  route `10.204.0.0/16` is auto-approved in the tailnet ACL. No manual route
  approval, and no auth key to expire.

---

# Run Tailscale on Render

![image](https://github.com/render-examples/tailscale/assets/168030/2513267e-6503-45c6-b596-3713160ae4ec)

[Tailscale](https://tailscale.com) is a zero-config VPN service built on top of [Wireguard](https://www.wireguard.com/). It's great for accessing devices and applications behind firewalls, and you can use it to connect to all your private services on Render with this repo.

A Tailscale [subnet router](https://tailscale.com/kb/1019/subnets/) acts as a gateway to your Render private network, enabling connections to any and all internal IPs (of the form `10.x.x.x`) in your Render network.

## Deployment

### One Click Deploy

Use the button below to deploy a Tailscale subnet router on Render. [Generate a Tailscale auth key](https://login.tailscale.com/admin/settings/authkeys) and enter it when prompted. Use a one-off key for maximum security.

<a href="https://render.com/deploy?repo=https://github.com/render-examples/tailscale/tree/main">
  <img src="https://render.com/images/deploy-to-render-button.svg" alt="Deploy to Render">
</a>

## Usage
Deploying this repo will create a subnet router in your Tailscale network. The first time you deploy, you'll need to [enable the subnet routes](https://tailscale.com/kb/1019/subnets/#step-3-enable-subnet-routes-from-the-admin-panel) you want access to from the Tailscale admin panel. Once the subnet router is up and running, you can connect to other private services in your Render network. To find the internal IP address for a Render private service, go to the web shell for your subnet router service and run `dig` with the [private service's host name](https://render.com/docs/private-services#connecting-to-a-private-service) as the only argument.

