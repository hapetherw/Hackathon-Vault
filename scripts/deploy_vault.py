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
    print("\nDeploying minimized Vault")

    # proxy admin account
    admin = accounts.load(
        click.prompt(
            "admin account",
            type=click.Choice(accounts.load())
        )
    )
    print(f"admin account: {admin.address}\n")

    # contract owner account
    owner = accounts.load(
        click.prompt(
            "owner account",
            type=click.Choice(accounts.load())
        )
    )
    print(f"contract owner account: {owner.address}\n")

    print(f"\nDeploying on {network.show_active()}:\n")

    # admin contract
    proxy_admin = ProxyAdmin.deploy(
        {'from': admin}
    )
    vault = Vault.deploy(
        {'from': owner}
    )
    proxy = TransparentUpgradeableProxy.deploy(
        vault.address,
        proxy_admin.address,
        eth_utils.to_bytes(hexstr="0x"),
        {'from': admin},
    )

    vault_proxy = Contract.from_abi("Vault", proxy.address, Vault.abi)
    txn = vault.initialize({'from': owner})
    txn = vault_proxy.initialize({'from': owner})


    # print("Adding Mocktoken as collateral")
    # mockToken = MockToken.deploy("MockToken", "MOCK", 18, {'from': owner})
    # txn = vault_proxy.addCollateral(
    #     mockToken,
    #     '0x0000000000000000000000000000000000000000', # _defaultStrategyAddr
    #     {'from': owner}
    # )
    # txn = MockToken.transfer(vault_proxy, MockToken.balanceOf(owner), {'from': owner})
