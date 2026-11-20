use anchor_lang::prelude::*;

declare_id!("EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB");

#[program]
pub mod originchain_registry {
    use super::*;

    pub fn register_asset(
        ctx: Context<RegisterAsset>,
        asset_id: [u8; 32],
        version_id: [u8; 32],
        content_hash: [u8; 32],
        manifest_hash: [u8; 32],
    ) -> Result<()> {
        require!(asset_id != [0; 32], RegistryError::InvalidIdentifier);
        require!(version_id != [0; 32], RegistryError::InvalidIdentifier);
        require!(content_hash != [0; 32], RegistryError::InvalidHash);
        require!(manifest_hash != [0; 32], RegistryError::InvalidHash);

        let now = Clock::get()?.unix_timestamp;
        let publisher = ctx.accounts.publisher.key();
        let origin = &mut ctx.accounts.origin;
        origin.authority = publisher;
        origin.asset_id = asset_id;
        origin.root_version_id = version_id;
        origin.version_count = 1;
        origin.bump = ctx.bumps.origin;

        let version = &mut ctx.accounts.version;
        version.origin = origin.key();
        version.publisher = publisher;
        version.version_id = version_id;
        version.parent_version_id = [0; 32];
        version.content_hash = content_hash;
        version.manifest_hash = manifest_hash;
        version.created_at = now;
        version.bump = ctx.bumps.version;
        Ok(())
    }

    pub fn append_version(
        ctx: Context<AppendVersion>,
        version_id: [u8; 32],
        content_hash: [u8; 32],
        manifest_hash: [u8; 32],
    ) -> Result<()> {
        require!(version_id != [0; 32], RegistryError::InvalidIdentifier);
        require!(content_hash != [0; 32], RegistryError::InvalidHash);
        require!(manifest_hash != [0; 32], RegistryError::InvalidHash);
        require!(
            content_hash != ctx.accounts.parent_version.content_hash,
            RegistryError::UnchangedContent
        );

        let origin = &mut ctx.accounts.origin;
        origin.version_count = origin
            .version_count
            .checked_add(1)
            .ok_or(RegistryError::VersionCountOverflow)?;

        let version = &mut ctx.accounts.version;
        version.origin = origin.key();
        version.publisher = ctx.accounts.publisher.key();
        version.version_id = version_id;
        version.parent_version_id = ctx.accounts.parent_version.version_id;
        version.content_hash = content_hash;
        version.manifest_hash = manifest_hash;
        version.created_at = Clock::get()?.unix_timestamp;
        version.bump = ctx.bumps.version;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(asset_id: [u8; 32], version_id: [u8; 32])]
pub struct RegisterAsset<'info> {
    #[account(mut)]
    pub fee_payer: Signer<'info>,
    pub publisher: Signer<'info>,
    #[account(
        init,
        payer = fee_payer,
        space = OriginRecord::SPACE,
        seeds = [b"origin", publisher.key().as_ref(), asset_id.as_ref()],
        bump
    )]
    pub origin: Account<'info, OriginRecord>,
    #[account(
        init,
        payer = fee_payer,
        space = VersionRecord::SPACE,
        seeds = [b"version", origin.key().as_ref(), version_id.as_ref()],
        bump
    )]
    pub version: Account<'info, VersionRecord>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(version_id: [u8; 32])]
pub struct AppendVersion<'info> {
    #[account(mut)]
    pub fee_payer: Signer<'info>,
    pub publisher: Signer<'info>,
    #[account(
        mut,
        seeds = [b"origin", publisher.key().as_ref(), origin.asset_id.as_ref()],
        bump = origin.bump,
        constraint = origin.authority == publisher.key() @ RegistryError::UnauthorizedPublisher
    )]
    pub origin: Account<'info, OriginRecord>,
    #[account(
        seeds = [b"version", origin.key().as_ref(), parent_version.version_id.as_ref()],
        bump = parent_version.bump,
        constraint = parent_version.origin == origin.key() @ RegistryError::WrongOrigin
    )]
    pub parent_version: Account<'info, VersionRecord>,
    #[account(
        init,
        payer = fee_payer,
        space = VersionRecord::SPACE,
        seeds = [b"version", origin.key().as_ref(), version_id.as_ref()],
        bump
    )]
    pub version: Account<'info, VersionRecord>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct OriginRecord {
    pub authority: Pubkey,
    pub asset_id: [u8; 32],
    pub root_version_id: [u8; 32],
    pub version_count: u32,
    pub bump: u8,
}

impl OriginRecord {
    pub const SPACE: usize = 8 + 32 + 32 + 32 + 4 + 1;
}

#[account]
pub struct VersionRecord {
    pub origin: Pubkey,
    pub publisher: Pubkey,
    pub version_id: [u8; 32],
    pub parent_version_id: [u8; 32],
    pub content_hash: [u8; 32],
    pub manifest_hash: [u8; 32],
    pub created_at: i64,
    pub bump: u8,
}

impl VersionRecord {
    pub const SPACE: usize = 8 + 32 + 32 + 32 + 32 + 32 + 32 + 8 + 1;
}

#[error_code]
pub enum RegistryError {
    #[msg("Asset and version identifiers cannot be zero.")]
    InvalidIdentifier,
    #[msg("Content and manifest hashes cannot be zero.")]
    InvalidHash,
    #[msg("The publisher does not control this asset.")]
    UnauthorizedPublisher,
    #[msg("The parent version belongs to a different origin.")]
    WrongOrigin,
    #[msg("Unchanged transfers must not create a new provenance version.")]
    UnchangedContent,
    #[msg("The version count has overflowed.")]
    VersionCountOverflow,
}
