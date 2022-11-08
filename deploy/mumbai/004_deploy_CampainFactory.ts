import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function ({ deployments, getNamedAccounts }) {
  const { deploy, get, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  const campaign = await get('Campaign');
  const link = await get('Link');
  const chainLinkRegistry = await get('ChainLinkRegistry');
  const chainLinkRegistrar = await get('ChainLinkRegistrar');

  await deploy('CampaignFactoryUpgradable', {
    from: deployer,
    args: [],
    proxy: {
      proxyContract: 'ERC1967Proxy',
      proxyArgs: ['{implementation}', '{data}'],
      execute: {
        init: {
          methodName: 'initialize',
          args: [campaign.address, link.address, chainLinkRegistrar.address, chainLinkRegistry.address],
        },
      },
    },
    log: true,
  });

  // set new campaign implementation
  await execute('CampaignFactoryUpgradable', { from: deployer, log: true }, 'updateCampaignImplementation', campaign.address);
};

func.tags = ['CampaignFactory'];
export default func;
