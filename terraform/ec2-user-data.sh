#!/bin/bash
# EC2 User Data - Worker Setup

# Update system
yum update -y

# Install Node.js
curl -sL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Install MySQL client
yum install -y mysql

# Create worker directory
mkdir -p /home/ec2-user/worker
cd /home/ec2-user/worker

# Create package.json
cat > package.json <<'EOF'
{
  "name": "ec2-worker",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@aws-sdk/client-sqs": "^3.0.0",
    "@aws-sdk/client-dynamodb": "^3.0.0",
    "@aws-sdk/lib-dynamodb": "^3.0.0",
    "@aws-sdk/client-sns": "^3.0.0",
    "mysql2": "^3.0.0"
  }
}
EOF

# Install dependencies
npm install

# Create worker script
cat > worker.js <<'WORKEREOF'
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import mysql from 'mysql2/promise';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

// Configuration
const REGION = 'eu-west-1';
const QUEUE_URL = process.env.LONG_TASKS_QUEUE_URL;
const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || 'ecommerce-orders';
const POLL_INTERVAL = 5000; // 5 secondes entre chaque poll

// SNS Topic ARNs
const ORDER_COMPLETED_TOPIC = process.env.SNS_ORDER_COMPLETED_TOPIC || 'arn:aws:sns:eu-west-1:165835313411:ecommerce-order-completed';
const ADMIN_ALERTS_TOPIC = process.env.SNS_ADMIN_ALERTS_TOPIC || 'arn:aws:sns:eu-west-1:165835313411:ecommerce-admin-alerts';

// Clients AWS
const sqsClient = new SQSClient({ region: REGION });
const dynamoClient = new DynamoDBClient({ region: REGION });
const dynamoDB = DynamoDBDocumentClient.from(dynamoClient);
const snsClient = new SNSClient({ region: REGION });

// RDS Configuration
const RDS_CONFIG = {
  host: process.env.RDS_HOST || 'ecommerce-analytics-db.xxxxxxxxx.eu-west-1.rds.amazonaws.com',
  user: process.env.RDS_USER || 'admin',
  password: process.env.RDS_PASSWORD || 'VOTRE_MOT_DE_PASSE',
  database: process.env.RDS_DATABASE || 'ecommerce',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// Pool de connexions MySQL
let mysqlPool = null;

async function getMySQLPool() {
  if (!mysqlPool) {
    mysqlPool = mysql.createPool(RDS_CONFIG);
    console.log('📊 MySQL connection pool created');
  }
  return mysqlPool;
}

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
    console.error('❌ Error processing order:', error)
    // Le message restera dans SQS et sera retraité
  } finally {
    currentOrder = null;
  }
}

async function processOrder(orderData) {
  const { orderId } = orderData;

  // ÉTAPE 1 : Update status to "processing"
  console.log('📋 Step 1/6: Starting order processing...');
  await updateOrderStatus(orderId, 'processing', 'Order processing started');
  await sleep(2000);
  // Notifier l'admin de la nouvelle commande
    try {
    await sendAdminNotification(orderData, 'new_order');
  } catch (error) {
    console.error('⚠️  Failed to send admin notification:', error.message);
  }

  // ÉTAPE 2 : Packaging simulation
  console.log('📦 Stpe 2/6: Packaging (simulating 30 seconds)...');
  await updateOrderStatus(orderId, 'packaging', 'Packaging in progress');
  await simulatePackaging();
  console.log('✅ Packaging complete');

  // ÉTAPE 3 : Shipping simulation
  console.log('🚚 Stpe 3/6: Shipping (simulating 1 minute)...');
  await updateOrderStatus(orderId, 'shipping', 'Order shipped');
  await simulateShipping();
  console.log('✅ Shipping complete');

  // ÉTAPE 4 : Mark as completed
  console.log('🎉 Stpe 4/6: Completing order...');
  await updateOrderStatus(orderId, 'completed', 'Order delivered');
  console.log('✅ Order completed successfully');

  // ÉTAPE 5 : Copy to RDS for analytics
  console.log('📊 Step 5/6: Copying to RDS for analytics...');
  try {
    await copyToRDS(orderId);
    console.log('✅ Order data copied to RDS\n');
  } catch (error) {
    console.error('⚠️  Failed to copy to RDS (non-blocking):', error.message);
  }
    // ÉTAPE 6 : Send notification email
  console.log('📧 Step 6/6: Sending notification email...');
  try {
    await sendOrderCompletedNotification(orderData);
    console.log('✅ Notification email sent\n');
  } catch (error) {
    console.error('⚠️  Failed to send notification (non-blocking):', error.message);
  }
}

async function simulatePackaging() {
 // Simulation de 30 secondes
  const PACKAGING_TIME = 30 * 1000; // 30 secondes in ms
  const STEPS = 6; // 6 étapes de 5 secondes
  const STEP_TIME = PACKAGING_TIME / STEPS;

  for (let i = 1; i <= STEPS; i++) {
    await sleep(STEP_TIME);
    const progress = Math.round((i / STEPS) * 100);
    process.stdout.write(`\r📦 Packaging progress: ${progress}%`);
  }
  console.log('');
}

async function simulateShipping() {
  // Simulation de 1 minute
  const SHIPPING_TIME = 60 * 1000; // 1 minute in ms
  const STEPS = 12; // 12 étapes de 5 secondes
  const STEP_TIME = SHIPPING_TIME / STEPS;

  for (let i = 1; i <= STEPS; i++) {
    await sleep(STEP_TIME);
    const progress = Math.round((i / STEPS) * 100);
    process.stdout.write(`\r🚚 Shipping progress: ${progress}%`);
  }
  console.log('');
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

async function copyToRDS(orderId) {
  // Récupérer les données complètes depuis DynamoDB
  const getCommand = new GetCommand({
    TableName: TABLE_NAME,
    Key: { orderId },
  });

  const result = await dynamoDB.send(getCommand);

  if (!result.Item) {
    throw new Error(`Order ${orderId} not found in DynamoDB`);
  }

  const order = result.Item;
  const pool = await getMySQLPool();

  // Insérer dans RDS
  const insertOrderQuery = `
    INSERT INTO orders (
      order_id, event_id, session_id, customer_id, customer_email, customer_name,
      amount_total, currency, payment_status, order_status,
      created_at, updated_at,
      processing_started_at, packaging_started_at, shipping_started_at, completed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
	  order_status = VALUES(order_status),
      updated_at = VALUES(updated_at),
      completed_at = VALUES(completed_at)
  `;

  const orderValues = [
    order.orderId,
    order.eventId,
    order.sessionId,
    order.customerId,
    order.customerEmail,
    order.customerName,
    order.amountTotal,
    order.currency,
    order.paymentStatus,
    order.orderStatus,
    order.createdAt,
    order.updatedAt,
    order.processingStartedAt || null,
    order.packagingStartedAt || null,
    order.shippingStartedAt || null,
    order.completedAt || null,
  ];

  await pool.execute(insertOrderQuery, orderValues);

  // Insérer les logs
  if (order.logs && order.logs.length > 0) {
    const insertLogQuery = `
      INSERT IGNORE INTO order_logs (order_id, status, message, timestamp)
      VALUES (?, ?, ?, ?)
    `;

    for (const log of order.logs) {
      await pool.execute(insertLogQuery, [
	    order.orderId,
        log.status,
        log.message,
        log.timestamp,
      ]);
    }
  }

  console.log(`✅ Order ${orderId} copied to RDS`);
}

async function sendOrderCompletedNotification(orderData) {
  const { orderId, customerEmail, customerName, amountTotal, currency } = orderData;

  // Message pour le client
  const subject = `✅ Your Order ${orderId} has been delivered!`;
  const message = `
Hello ${customerName || 'Customer'},

Great news! Your order has been successfully delivered! 🎉

Order Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Order ID: ${orderId}
Amount: ${(amountTotal / 100).toFixed(2)} ${currency.toUpperCase()}
Status: ✅ DELIVERED

Timeline:
- Order Received: ✓
- Payment Confirmed: ✓
- Packaging Complete: ✓
- Shipped: ✓
- Delivered: ✓

Thank you for shopping with us!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Questions? Contact us at support@ecommerce.com

Best regards,
The E-commerce Team
  `.trim();

  // Publier sur SNS
  const publishCommand = new PublishCommand({
    TopicArn: ORDER_COMPLETED_TOPIC,
    Subject: subject,
    Message: message,
    MessageAttributes: {
      orderId: {
        DataType: 'String',
        StringValue: orderId,
      },
      customerEmail: {
        DataType: 'String',
        StringValue: customerEmail || 'unknown',
      },
    },
  });

  await snsClient.send(publishCommand);
  console.log(`📧 Notification sent for order ${orderId}`);
}

async function sendAdminNotification(orderData, type) {
  const { orderId, customerEmail, amountTotal, currency } = orderData;

  let subject, message;

  if (type === 'new_order') {
    subject = `🛒 New Order: ${orderId}`;
    message = `
New order received!

Order ID: ${orderId}
Customer: ${customerEmail}
Amount: ${(amountTotal / 100).toFixed(2)} ${currency.toUpperCase()}
Status: Processing

View in Dashboard: [Link to Admin Panel]
    `.trim();
  } else if (type === 'error') {
    subject = `❌ Order Processing Error: ${orderId}`;
    message = `Error processing order ${orderId}. Please check logs.`;
  }

  const publishCommand = new PublishCommand({
    TopicArn: ADMIN_ALERTS_TOPIC,
    Subject: subject,
    Message: message,
  });

  await snsClient.send(publishCommand);
}
// Start the worker
main().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
WORKEREOF

# Create systemd service
cat > /etc/systemd/system/ec2-worker.service <<EOF
[Unit]
Description=E-commerce Order Processing Worker
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/worker
Environment="LONG_TASKS_QUEUE_URL=${sqs_queue_url}"
Environment="DYNAMODB_TABLE_NAME=${dynamodb_table}"
Environment="RDS_HOST=${rds_host}"
Environment="RDS_USER=${rds_username}"
Environment="RDS_PASSWORD=${rds_password}"
Environment="RDS_DATABASE=${rds_database}"
Environment="SNS_ORDER_COMPLETED_TOPIC=${sns_order_completed_topic}"
Environment="SNS_ADMIN_ALERTS_TOPIC=${sns_admin_alerts_topic}"
ExecStart=/usr/bin/node worker.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user/worker

# Enable and start service
systemctl daemon-reload
systemctl enable ec2-worker
systemctl start ec2-worker