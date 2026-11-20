# Brand — OriginChain

OriginChain helps creators register and verify the provenance of digital assets.

_Defined on 2026-11-20. Update by revisiting `brand.md` and the app theme._

## Palette — Clay & Cream

**Vibe:** warm · editorial · confident
**Category:** consumer / social
**Mood:** warm

### Seeds

| Role | Light | Dark |
|---|---|---|
| Background | `#F8F3ED` | `#171311` |
| Elevated surface | `#FFFCF8` | `#221B17` |
| Primary | `#91452F` | `#DDA28D` |
| Soft primary | `#D28B6E` | `#E7B8A7` |
| Main text | `#281C17` | `#F7EEE8` |

### Interface tokens

| Token | Light | Dark |
|---|---|---|
| Background | `#F8F3ED` | `#171311` |
| Surface / card | `#FFFCF8` | `#221B17` |
| Main text | `#281C17` | `#F7EEE8` |
| Muted text | `#69564D` | `#C5B4AA` |
| Primary action | `#91452F` | `#DDA28D` |
| Primary action text | `#FFFFFF` | `#2A1711` |
| Border | `#E6D9CF` | `#493A32` |

The Flutter implementation lives in `lib/core/theme/origin_theme.dart`. Light and dark modes follow the device by default; users can also choose a mode in Profile.

## Typography

Use a clean, friendly sans serif with compact headings and high legibility. Gumroad's current web design is reported to use ABC Favorit; OriginChain uses the platform's native sans on mobile to avoid licensing and runtime font downloads. Use **DM Sans** as the close web app match. Use a system monospace for fingerprints and identifiers.

## Gradients and materials

- Soft background: `linear-gradient(135deg, #F8F3ED 0%, #EFE4DA 100%)`
- Clay accent: `linear-gradient(110deg, #91452F 0%, #C57B5F 100%)`
- Keep translucent glass to navigation and important floating controls. Keep content cards solid and readable.
- Use broad, soft corner radii; avoid sharp corners and heavy shadows.

## Voice

Be human, clear, and encouraging. Speak to the creator as “you.” Explain what an action does and what stays private. Avoid corporate language, hype, and claims that a file is registered or verified until cryptographic evidence supports that status.

## Product rules that affect the interface

- Hash files on device. Never upload original content automatically.
- Wallet connection is optional.
- OriginChain's platform pays all Solana network and transaction fees. Do not ask users to pay them or hold SOL for registration.
- Firebase records are application projections. Cryptographic provenance and Solana commitments remain independently verifiable.
