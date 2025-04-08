const { expect } = require("chai");

describe("JewelryLifecycle Contract", function () {
  let contract, deployer, miningCompany, cuttingCompany, gradingLab, jewelryMaker, buyer;

  beforeEach(async function () {
    const JewelryLifecycle = await ethers.getContractFactory("JewelryLifecycle");
    [deployer, miningCompany, cuttingCompany, gradingLab, jewelryMaker, buyer] = await ethers.getSigners();

    // 部署合约
    contract = await JewelryLifecycle.deploy();
    await contract.deployed();

    // 设置角色
    await contract.setRoles(
      miningCompany.address,
      cuttingCompany.address,
      gradingLab.address,
      jewelryMaker.address
    );
  });

  it("Should allow mining company to create jewelry", async function () {
    await contract.connect(miningCompany).createJewelry("Diamond");
    const jewelry = await contract.jewelries(1);
    expect(jewelry.description).to.equal("Diamond");
    expect(jewelry.status).to.equal(0); // MINED
    expect(jewelry.currentOwner).to.equal(miningCompany.address);
  });

  it("Should allow cutting company to update status to POLISHED", async function () {
    await contract.connect(miningCompany).createJewelry("Ruby");
    await contract.connect(cuttingCompany).updateStatusToPolished(1);
    const jewelry = await contract.jewelries(1);
    expect(jewelry.status).to.equal(1); // POLISHED
  });

  it("Should allow grading lab to generate certificate", async function () {
    await contract.connect(miningCompany).createJewelry("Emerald");
    await contract.connect(cuttingCompany).updateStatusToPolished(1);
    await contract.connect(gradingLab).generateCertificate(1, 12345);
    const jewelry = await contract.jewelries(1);
    expect(jewelry.CAId).to.equal(12345);
    expect(jewelry.status).to.equal(2); // GRADED
  });

  it("Should allow jewelry maker to update status to IN_STOCK", async function () {
    await contract.connect(miningCompany).createJewelry("Sapphire");
    await contract.connect(cuttingCompany).updateStatusToPolished(1);
    await contract.connect(gradingLab).generateCertificate(1, 67890);
    await contract.connect(jewelryMaker).updateStatusToInStock(1);
    const jewelry = await contract.jewelries(1);
    expect(jewelry.status).to.equal(3); // IN_STOCK
  });

  it("Should allow transferring ownership", async function () {
    await contract.connect(miningCompany).createJewelry("Amethyst");
    await contract.connect(cuttingCompany).updateStatusToPolished(1);
    await contract.connect(gradingLab).generateCertificate(1, 54321);
    await contract.connect(jewelryMaker).updateStatusToInStock(1);
    await contract.connect(jewelryMaker).transferOwnership(1, buyer.address);
    const jewelry = await contract.jewelries(1);
    expect(jewelry.currentOwner).to.equal(buyer.address);
    expect(jewelry.status).to.equal(5); // SOLD
  });

  it("Should revert if unauthorized user tries to update status", async function () {
    await contract.connect(miningCompany).createJewelry("Topaz");
    await expect(contract.connect(buyer).updateStatusToPolished(1)).to.be.revertedWith("Not authorized");
  });
});
