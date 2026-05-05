# App Store Distribution Notes

Anigma maintains dual-licensing to permit commercial deployment, particularly for environments like the Apple App Store where GPL/AGPL copyleft restrictions conflict with App Store Terms of Service.

## Compliance Strategy
1. **Dependency Hygiene**: No third-party GPL/AGPL code may be bundled into the iOS/macOS runtime target unless explicitly isolated in a way that legally satisfies App Store requirements (which is exceedingly rare and generally avoided).
2. **Dual-Licensing Model**: The core Anigma codebase is AGPL for open source, but the proprietary commercial builds submitted to the App Store are licensed commercially, absolving users of AGPL distribution requirements.
3. **Inventory Sweeps**: Prior to any App Store release, the `THIRD_PARTY_INVENTORY.yaml` must be verified. All components marked `distributed_in_app_store_build: true` must be clear of copyleft risk.
