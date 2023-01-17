const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Desert Explorer Unit Tests", function () {
          let game, deployer

          beforeEach(async () => {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
              player = accounts[1]
              await deployments.fixture(["all"])
              game = await ethers.getContract("DesertExplorer")
              generals = await ethers.getContract("VerdomiGenerals")
              vgold = await ethers.getContract("VGOLD")
              zeroAddress = "0x0000000000000000000000000000000000000000"

              await generals.addAllowed(deployer.address)
              await generals.mintGeneral(deployer.address, 20)
              await generals.addAllowed(game.address)
              await vgold.addAllowed(game.address)
          })

          describe("Constructor", () => {
              it("Sets the expedition time correctly", async () => {
                  const time = await game.getExpeditionTime()
                  assert.equal(time, 60)
              })
              it("Sets the VerdomiGenerals address correctly", async () => {
                  const address = await game.getVerdomiGeneralsAddress()
                  assert.equal(address, generals.address)
              })
              it("Sets the VGOLD address correctly", async () => {
                  const address = await game.getVgoldAddress()
                  assert.equal(address, vgold.address)
              })
          })

          describe("toggleOpen", () => {
              it("Correctly toggles the open variable", async () => {
                  const before = await game.isContractOpen()
                  await game.toggleOpen()
                  const after = await game.isContractOpen()
                  await game.toggleOpen()
                  const afterAgain = await game.isContractOpen()

                  assert.equal(before.toString(), "true")
                  assert.equal(after.toString(), "false")
                  assert.equal(afterAgain.toString(), "true")
              })
              it("Reverts if not owner", async () => {
                  const playerGame = game.connect(player)
                  await expect(playerGame.toggleOpen()).to.be.reverted
              })
          })

          describe("setExpeditionTime", () => {
              it("Reverts if not owner", async () => {
                  const playerGame = game.connect(player)
                  await expect(playerGame.setExpeditionTime(5)).to.be.reverted
              })
              it("Correctly changes the expedition time", async () => {
                  const before = await game.getExpeditionTime()
                  await game.setExpeditionTime(5)
                  const after = await game.getExpeditionTime()
                  assert.equal(before, 60)
                  assert.equal(after, 5)
              })
          })

          describe("startMultipleExpeditions", () => {
              it("Reverts if not open", async () => {
                  await game.toggleOpen()
                  await expect(game.startMultipleExpeditions([0])).to.be.reverted
                  await expect(game.startMultipleExpeditions([0, 1, 2, 3])).to.be.reverted
              })
              it("Reverts if not owner of token", async () => {
                  const playerGame = game.connect(player)
                  await expect(playerGame.startMultipleExpeditions([0])).to.be.reverted

                  await generals.transferFrom(deployer.address, player.address, 1)
                  await expect(game.startMultipleExpeditions([0, 1, 2, 3])).to.be.reverted
              })
              it("Reverts if token on expedition already", async () => {
                  await game.startMultipleExpeditions([0])
                  await expect(game.startMultipleExpeditions([0])).to.be.reverted
              })
              it("Correctly sets a start time for the tokenId", async () => {
                  const before1 = await game.tokenExpeditionStart(0)
                  await game.startMultipleExpeditions([0])
                  const after1 = await game.tokenExpeditionStart(0)
                  const before2 = await game.tokenExpeditionStart(2)
                  await game.startMultipleExpeditions([1, 2, 3, 4])
                  const after2 = await game.tokenExpeditionStart(2)

                  assert.equal(before1, 0)
                  assert(after1 > 0)
                  assert.equal(before2, 0)
                  assert(after2 > 0)
              })
          })

          describe("completeMultipleExpeditions", () => {
              it("Reverts if not finished", async () => {
                  await game.startMultipleExpeditions([0])
                  await game.startMultipleExpeditions([1, 2, 3, 4])
                  await expect(game.completeMultipleExpeditions([0])).to.be.reverted
                  await expect(game.completeMultipleExpeditions([3])).to.be.reverted
              })
              it("Reverts if token is not on an expedition", async () => {
                  await expect(game.completeMultipleExpeditions([0])).to.be.reverted
              })
              it("Sets the start time to 0 for the token", async () => {
                  await game.startMultipleExpeditions([0])
                  const before = await game.tokenExpeditionStart(0)
                  await game.setExpeditionTime(0)
                  game.completeMultipleExpeditions([0])
                  const after = await game.tokenExpeditionStart(0)

                  assert(before > 0)
                  assert.equal(after, 0)
              })
              it("Sends the owner of the token at least 100 VGOLD", async () => {
                  await game.startMultipleExpeditions([0])
                  const before = await vgold.balanceOf(deployer.address)
                  await game.setExpeditionTime(0)
                  game.completeMultipleExpeditions([0])
                  const after = await vgold.balanceOf(deployer.address)

                  assert(after >= before + 100 * 10 ** 18)
              })
              it("Emits an event if successful", async () => {
                  await game.startMultipleExpeditions([0])
                  const before = await vgold.balanceOf(deployer.address)
                  await game.setExpeditionTime(0)
                  expect(game.completeMultipleExpeditions([0])).to.emit(game, "ExpeditionCompleted")
              })
          })
      })

/*




*/
