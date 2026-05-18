'use strict';
const express = require('express');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.use(express.json({ limit: '10mb' }));

const GRPC_ADDR = `${process.env.GRPC_HOST || 'localhost'}:${process.env.GRPC_PORT || '50051'}`;
const PROTO_PATH = process.env.PROTO_PATH || '/app/src/proto/openclaude.proto';
const PORT = parseInt(process.env.HTTP_PORT || '8080', 10);

let grpcClient = null;

function createClient() {
  const pkgDef = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });
  const proto = grpc.loadPackageDefinition(pkgDef);

  function findService(obj, name) {
    if (!obj || typeof obj !== 'object') return null;
    if (obj[name] && typeof obj[name] === 'function') return obj[name];
    for (const v of Object.values(obj)) {
      const found = findService(v, name);
      if (found) return found;
    }
    return null;
  }

  const AgentService = findService(proto, 'AgentService');
  if (!AgentService) throw new Error('AgentService not found in proto');
  return new AgentService(GRPC_ADDR, grpc.credentials.createInsecure());
}

function getClient() {
  if (!grpcClient) grpcClient = createClient();
  return grpcClient;
}

function resolveSystemPrompt(body) {
  const type = body.prompt_type || 'code-review';
  const depth = body.depth || 'quick';
  if (type === 'alert-triage') return process.env.PROMPT_ALERT_TRIAGE || '';
  if (type === 'backup-digest') return process.env.PROMPT_BACKUP_DIGEST || '';
  if (type === 'manifest-validation') return process.env.PROMPT_MANIFEST_VALIDATION || '';
  return depth === 'deep'
    ? (process.env.REVIEW_PROMPT_DEEP || '')
    : (process.env.REVIEW_PROMPT_QUICK || '');
}

async function callOpenClaude(body) {
  const depth = body.depth || 'quick';
  const timeoutMs = depth === 'deep' ? 300_000 : 120_000;
  const model = depth === 'deep'
    ? (process.env.DEEP_MODEL || 'glm-5-turbo')
    : (process.env.QUICK_MODEL || 'qwen2.5-coder:7b');

  const systemPrompt = resolveSystemPrompt(body);
  const sessionId = body.commit_sha || crypto.randomUUID();
  const workingDir = `/tmp/review-${body.pr_number || Date.now()}`;

  let userMessage = body.diff || '';
  if (body.context) userMessage = `${body.context}\n\n---\n\n${userMessage}`;

  return new Promise((resolve, reject) => {
    const stream = getClient().Chat();
    let reviewText = '';
    let modelUsed = model;
    let tokensUsed = 0;
    let settled = false;

    const settle = (fn) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      fn();
    };

    const timer = setTimeout(() => {
      settle(() => {
        try { stream.cancel(); } catch (_) {}
        reject(new Error(`Review timed out after ${timeoutMs / 1000}s`));
      });
    }, timeoutMs);

    stream.on('data', (msg) => {
      if (msg.text_chunk) {
        reviewText += msg.text_chunk.text || '';
      } else if (msg.action_required) {
        // Auto-approve all tool permission prompts in headless mode
        stream.write({
          user_input: {
            prompt_id: msg.action_required.prompt_id,
            response: 'yes',
          },
        });
      } else if (msg.done) {
        modelUsed = msg.done.model || model;
        tokensUsed = msg.done.total_tokens || 0;
        settle(() => {
          try { stream.end(); } catch (_) {}
          resolve({ review_text: reviewText, model_used: modelUsed, tokens_used: tokensUsed });
        });
      } else if (msg.error) {
        settle(() => {
          try { stream.end(); } catch (_) {}
          reject(new Error(msg.error.message || 'OpenClaude returned an error'));
        });
      }
    });

    stream.on('error', (err) => {
      settle(() => reject(err));
    });

    stream.on('end', () => {
      settle(() => resolve({ review_text: reviewText, model_used: modelUsed, tokens_used: tokensUsed }));
    });

    stream.write({
      request: {
        message: userMessage,
        session_id: sessionId,
        working_directory: workingDir,
        system_prompt: systemPrompt,
        model,
      },
    });
  });
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.post('/review', async (req, res) => {
  if (!req.body.diff) {
    return res.status(400).json({ error: 'Missing required field: diff' });
  }
  try {
    const result = await callOpenClaude(req.body);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => console.log(`HTTP adapter on :${PORT}, gRPC → ${GRPC_ADDR}`));
