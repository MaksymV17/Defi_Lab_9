// Лабораторна №9: DAO змінює комісію MockProtocol через голосування.
// Запуск: npm run lab   (локальна мережа Hardhat піднімається автоматично)
const fs = require("node:fs");
const { ethers, network } = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners(); // розгортає контракти й тримає governance-токени
  console.log("Акаунт:", owner.address);

  // 1. Governance-токен (VertiiCoin з попередніх робіт) і SimpleDAO
  const token = await (await ethers.getContractFactory("AssetToken"))
    .deploy("VertiiCoin", "VRT", ethers.parseUnits("10000", 18));
  await token.waitForDeployment();
  const dao = await (await ethers.getContractFactory("SimpleDAO")).deploy(await token.getAddress());
  await dao.waitForDeployment();
  console.log("VertiiCoin (VRT):", await token.getAddress());
  console.log("SimpleDAO:       ", await dao.getAddress());

  // 2. MockProtocol (початкова комісія 3)
  const protocol = await (await ethers.getContractFactory("MockProtocol")).deploy(3);
  await protocol.waitForDeployment();
  console.log("MockProtocol:    ", await protocol.getAddress());
  console.log("fee до зміни:    ", (await protocol.fee()).toString());

  // 3. Передача прав власності DAO
  await (await protocol.transferOwnership(await dao.getAddress())).wait();
  console.log("Власник MockProtocol:", await protocol.owner(), "(це SimpleDAO)");

  // Перевірка: прямий виклик setFee від звичайного акаунта має бути відхилений
  try {
    await protocol.setFee.staticCall(99);
    console.log("ПОМИЛКА: прямий виклик setFee пройшов");
  } catch {
    console.log("Прямий виклик setFee(99) від звичайного акаунта відхилено - добре");
  }

  // 4. createProposal: кодуємо виклик setFee(10)
  const data = protocol.interface.encodeFunctionData("setFee", [10]);
  const txCreate = await dao.createProposal(await protocol.getAddress(), data, "Змінити комісію протоколу на 10");
  const rc = await txCreate.wait();
  const id = await dao.proposalCount();
  console.log(`\nПропозицію #${id} створено, tx: ${rc.hash}`);

  // 5. Голосування "за" з гаманця, що має токени
  const txVote = await dao.vote(id, true);
  await txVote.wait();
  const p = await dao.getProposal(id);
  console.log(`Голос "за" віддано, tx: ${txVote.hash}`);
  console.log("Голосів за:", ethers.formatUnits(p.votesFor, 18), "VRT, проти:", ethers.formatUnits(p.votesAgainst, 18));

  // 6. Очікування завершення голосування (1 хвилина) - перемотуємо час локальної мережі
  const period = Number(await dao.VOTING_PERIOD());
  await network.provider.send("evm_increaseTime", [period + 1]);
  await network.provider.send("evm_mine", []);
  console.log(`Час мережі перемотано на ${period + 1} с (голосування завершено)`);

  const txExec = await dao.executeProposal(id);
  await txExec.wait();
  console.log(`executeProposal виконано, tx: ${txExec.hash}`);

  const feeAfter = await protocol.fee();
  console.log("\n==> fee після виконання пропозиції:", feeAfter.toString());

  fs.writeFileSync("deployment-lab9.json", JSON.stringify({
    token: await token.getAddress(), dao: await dao.getAddress(), protocol: await protocol.getAddress(),
    proposalId: id.toString(), createTx: rc.hash, voteTx: txVote.hash, executeTx: txExec.hash,
    feeAfter: feeAfter.toString(),
  }, null, 2));
  console.log("Дані збережено у deployment-lab9.json");
}

main().catch((e) => { console.error(e); process.exit(1); });
