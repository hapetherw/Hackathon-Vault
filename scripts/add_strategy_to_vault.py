import signal
import click
from brownie import (
    ProxyAdmin,
    TransparentUpgradeableProxy,
    MockToken,
    Vault,
    accounts,
    network,
    Contract
)
import eth_utils

def main():
    # contract owner account
    owner = accounts.load(
        click.prompt(
            "owner account",
            type=click.Choice(accounts.load())
        )
    )
    vault_addr = input("Enter your vault address: ")
    strategy_addr = input("Enter your strategy address: ")
    collateral_addr = input("Enter your collateral address: ")
    vault_proxy = Contract.from_abi("Vault", vault_addr, Vault.abi)
    txn = vault_proxy.addCollateral(
        collateral_addr,
        strategy_addr,
        {'from': owner}
    )
    txn = vault_proxy.addStrategy(
        strategy_addr,
        {'from': owner}
    )
