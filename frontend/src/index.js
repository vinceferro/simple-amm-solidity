import { ethers } from "ethers"
import RouterJSON from '../../artifacts/contracts/SpaceRouter.sol/SpaceRouter.json'
import ICOJSON from '../../artifacts/contracts/SpaceCoinICO.sol/SpaceCoinICO.json'
import LPJSON from '../../artifacts/contracts/SpaceLP.sol/SpaceLP.json'
import TokenJSON from '../../artifacts/contracts/SpaceCoinToken.sol/SpaceCoinToken.json'


const provider = new ethers.providers.Web3Provider(window.ethereum)
const signer = provider.getSigner()

const routerAddr = '0x6F014797d5D8731Ae8Cce4d22f7A5bB27349751f'
const routerContract = new ethers.Contract(routerAddr, RouterJSON.abi, provider);

const icoAddr = '0x7fd3734a66C6880658D804A017ac3A85a10B6c78'
const icoContract = new ethers.Contract(icoAddr, ICOJSON.abi, provider);

const lpAddr = '0x6f015D3423bE8B2F4cC759eac7d80723E2f1f6CF'
const lpContract = new ethers.Contract(lpAddr, LPJSON.abi, provider);

const tokenAddr = '0x17e3Af701028E804aCAeD7350838A84DF7DA5F3D'
const tokenContract = new ethers.Contract(tokenAddr, TokenJSON.abi, provider);

async function connectToMetamask() {
  try {
    console.log("Signed in as", await signer.getAddress())
  }
  catch(err) {
    console.log("Not signed in")
    await provider.send("eth_requestAccounts", [])
  }
}



//
// ICO
//
ico_spc_buy.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const eth = ethers.utils.parseEther(form.eth.value)
  console.log("Buying", eth, "eth")

  await connectToMetamask()
  await icoContract.connect(signer).invest({value: eth})
})


//
// LP
//
let currentSpcToEthPrice = 5

provider.on("block", n => {
  console.log("New block", n)
  lpContract.getReserves()
    .then(res => {
      currentSpcToEthPrice = res[1] > 0 ? res[0].div(res[1]).toNumber() : 5
      updateSwapOutLabel()
    })
})

lp_deposit.eth.addEventListener('input', e => {
  lp_deposit.spc.value = +e.target.value * currentSpcToEthPrice
})

lp_deposit.spc.addEventListener('input', e => {
  lp_deposit.eth.value = +e.target.value / currentSpcToEthPrice
})

lp_deposit.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const eth = ethers.utils.parseEther(form.eth.value)
  const spc = ethers.utils.parseEther(form.spc.value)
  console.log("Depositing", eth, "eth and", spc, "spc")

  await connectToMetamask()

  const allowance = await tokenContract.connect(signer).allowance(await signer.getAddress(), routerAddr)
  if (allowance < spc) {
    await tokenContract.connect(signer).approve(routerAddr, spc)
  }

  await routerContract.connect(signer).addLiquidity(eth, spc, {value: eth})
})

lp_withdraw.addEventListener('submit', async e => {
  e.preventDefault()
  console.log("Withdrawing 100% of LP")

  await connectToMetamask()
  const amount = lpContract.connect(signer).balanceOf(await signer.getAddress())
  await routerContract.connect(signer).removeLiquidity(amount, 0, 0)
})

//
// Swap
//
let swapIn = { type: 'eth', value: 0 }
let swapOut = { type: 'spc', value: 0 }
switcher.addEventListener('click', () => {
  [swapIn, swapOut] = [swapOut, swapIn]
  swap_in_label.innerText = swapIn.type.toUpperCase()
  swap.amount_in.value = swapIn.value
  updateSwapOutLabel()
})

swap.amount_in.addEventListener('input', updateSwapOutLabel)

function updateSwapOutLabel() {
  swapOut.value = swapIn.type === 'eth'
    ? +swap.amount_in.value * currentSpcToEthPrice
    : +swap.amount_in.value / currentSpcToEthPrice

  swap_out_label.innerText = `${swapOut.value} ${swapOut.type.toUpperCase()}`
}

swap.addEventListener('submit', async e => {
  e.preventDefault()
  const form = e.target
  const amountIn = ethers.utils.parseEther(form.amount_in.value)

  console.log("Swapping", amountIn, swapIn.type, "for", swapOut.type)

  await connectToMetamask()
  if (swapIn.type === 'eth') {
    await routerContract.connect(signer).swapETHforSPC(amountIn, swapOut.value, {value: amountIn})
  } else {
    await routerContract.connect(signer).swapSPCforEth(amountIn, swapOut.value)
  }
})
