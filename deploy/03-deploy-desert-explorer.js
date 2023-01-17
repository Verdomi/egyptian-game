const { network } = require("hardhat")
const { networkConfig, developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    log("------------------------")

    let generalAddress
    let vgoldAddress

    if (developmentChains.includes(network.name)) {
        const generals = await deployments.get("VerdomiGenerals")
        generalAddress = generals.address
        const vgold = await deployments.get("VGOLD")
        vgoldAddress = vgold.address
    } else {
        generalAddress = networkConfig[chainId]["VerdomiGeneralsAddress"]
        vgoldAddress = networkConfig[chainId]["VgoldAddress"]
    }

    const expTime = 60

    const args = [vgoldAddress, generalAddress, expTime]
    const explorer = await deploy("DesertExplorer", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(explorer.address, args)
    }
    log("------------------------")
}

module.exports.tags = ["all", "explorer", "main"]
