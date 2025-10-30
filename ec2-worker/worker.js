import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand, GetCommand } from '@aws-sdk/lib-dynamodb';

// Configuration
const REGION = 'eu-west-1';
const QUEUE_URL = process.env.LONG_TASKS_QUEUE_URL;
const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || 'ecommerce-orders';
const POLL_INTERVAL = 5000; // 5 secondes entre chaque poll

// Clients AWS
const sqsClient = new SQSClient({ region: REGION });
const dynamoClient = new DynamoDBClient({ region: REGION });
const dynamoDB = DynamoDBDocumentClient.from(dynamoClient);

// État du worker
let isRunning = true;
let currentOrder = null;

console.log('🚀 EC2 Worker Starting...');
console.log('📍 Region:', REGION);
console.log('📦 Queue URL:', QUEUE_URL);
console.log('🗄️  DynamoDB Table:', TABLE_NAME);
console.log('');

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n⚠️  Received SIGINT, shutting down gracefully...');
  isRunning = false;
});

process.on('SIGTERM', () => {
  console.log('\n⚠️  Received SIGTERM, shutting down gracefully...');
  isRunning = false;
});

// Main loop
async function main() {
  console.log('✅ Worker started, polling for messages...\n');

  while (isRunning) {
    try {
      await pollAndProcess();
      await sleep(POLL_INTERVAL);
    } catch (error) {
      console.error('❌ Error in main loop:', error);
      await sleep(10000); // Wait longer on error
    }
  }

  console.log('👋 Worker stopped');
  process.exit(0);
}

async function pollAndProcess() {
  // Poll SQS
  const command = new ReceiveMessageCommand({
    QueueUrl: QUEUE_URL,
    MaxNumberOfMessages: 1,
    WaitTimeSeconds: 20, // Long polling
    MessageAttributeNames: ['All'],
  });

  const response = await sqsClient.send(command);

  if (!response.Messages || response.Messages.length === 0) {
    // Pas de messages
    process.stdout.write('.');
    return;
  }

  const message = response.Messages[0];
  console.log('\n📨 New message received');

  try {
    const orderData = JSON.parse(message.Body);
    currentOrder = orderData;

    console.log('🆔 Order ID:', orderData.orderId);
    console.log('📧 Customer:', orderData.customerEmail);
    console.log('💰 Amount:', orderData.amountTotal / 100, orderData.currency);
    console.log('');

    // Process the order
    await processOrder(orderData);

    // Delete message from SQS (traitement réussi)
    await deleteMessage(message.ReceiptHandle);
    console.log('✅ Message deleted from queue\n');

  } catch (error) {
    console.error('❌ Error processing order:', error);
    // Le message restera dans SQS et sera retraité
  } finally {
    currentOrder = null;
  }
}

async function processOrder(orderData) {
  const { orderId } = orderData;

  // ÉTAPE 1 : Update status to "processing"
  console.log('📋 Step 1/4: Starting order processing...');
  await updateOrderStatus(orderId, 'processing', 'Order processing started');
  await sleep(2000);

  // ÉTAPE 2 : Packaging simulation (3 minutes)
  console.log('📦 Step 2/4: Packaging (simulating 3 minutes)...');
  await updateOrderStatus(orderId, 'packaging', 'Packaging in progress');
  await simulatePackaging();
  console.log('✅ Packaging complete');

  // ÉTAPE 3 : Shipping simulation (10 minutes)
  console.log('🚚 Step 3/4: Shipping (simulating 10 minutes)...');
  await updateOrderStatus(orderId, 'shipping', 'Order shipped');
  await simulateShipping();
  console.log('✅ Shipping complete');

  // ÉTAPE 4 : Mark as completed
  console.log('🎉 Step 4/4: Completing order...');
  await updateOrderStatus(orderId, 'completed', 'Order delivered');
  console.log('✅ Order completed successfully\n');
}

async function simulatePackaging() {
  // Simulation de 3 minutes
  const PACKAGING_TIME = 3 * 60 * 1000; // 3 minutes in ms
  const STEPS = 6; // 6 étapes de 30 secondes
  const STEP_TIME = PACKAGING_TIME / STEPS;

  for (let i = 1; i <= STEPS; i++) {
    await sleep(STEP_TIME);
    const progress = Math.round((i / STEPS) * 100);
    process.stdout.write(`\r📦 Packaging progress: ${progress}%`);
  }
  console.log(''); // Nouvelle ligne
}

async function simulateShipping() {
  // Simulation de 10 minutes
  const SHIPPING_TIME = 10 * 60 * 1000; // 10 minutes in ms
  const STEPS = 20; // 20 étapes de 30 secondes
  const STEP_TIME = SHIPPING_TIME / STEPS;

  for (let i = 1; i <= STEPS; i++) {
    await sleep(STEP_TIME);
    const progress = Math.round((i / STEPS) * 100);
    process.stdout.write(`\r🚚 Shipping progress: ${progress}%`);
  }
  console.log(''); // Nouvelle ligne
}

async function updateOrderStatus(orderId, status, message) {
  const timestamp = new Date().toISOString();

  const command = new UpdateCommand({
    TableName: TABLE_NAME,
    Key: { orderId },
    UpdateExpression: 'SET orderStatus = :status, updatedAt = :timestamp, logs = list_append(if_not_exists(logs, :empty_list), :log)',
    ExpressionAttributeValues: {
      ':status': status,
      ':timestamp': timestamp,
      ':log': [{
        timestamp: timestamp,
        status: status,
        message: message,
      }],
      ':empty_list': [],
    },
  });

  await dynamoDB.send(command);
  console.log(`✅ Status updated: ${status}`);
}

async function deleteMessage(receiptHandle) {
  const command = new DeleteMessageCommand({
    QueueUrl: QUEUE_URL,
    ReceiptHandle: receiptHandle,
  });

  await sqsClient.send(command);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Start the worker
main().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});