from flask import Flask, request, jsonify
from flask_cors import CORS
import uuid
import time
import os

app = Flask(__name__)
CORS(app)

# Simulated in-memory storage of nodes and messages
nodes = {}
messages = set()
message_store = []

@app.route('/register', methods=['POST'])
def register_node():
    data = request.json
    node_id = data.get('node_id', str(uuid.uuid4()))
    nodes[node_id] = {
        'last_seen': time.time()
    }
    return jsonify({'status': 'ok', 'node_id': node_id})

@app.route('/broadcast', methods=['POST'])
def broadcast_message():
    data = request.json
    message_id = data.get('message_id') or data.get('messageId')
    
    if not message_id:
        return jsonify({'status': 'error', 'message': 'Missing message_id'}), 400
        
    # Find if message exists to update it
    existing_msg = next((m for m in message_store if (m.get('message_id') == message_id or m.get('messageId') == message_id)), None)
    
    if existing_msg:
        changed = False
        for k, v in data.items():
            if existing_msg.get(k) != v:
                existing_msg[k] = v
                changed = True
        if changed:
            return jsonify({'status': 'updated', 'message_id': message_id})
        return jsonify({'status': 'ignored', 'message': 'No changes detected'})
        
    messages.add(message_id)
    message_store.append(data)
    
    return jsonify({'status': 'broadcasted', 'message_id': message_id})


@app.route('/sync', methods=['GET'])
def sync_messages():
    node_id = request.args.get('node_id')
    if node_id:
        nodes[node_id] = {'last_seen': time.time()}
        
    # Return all messages (in a real mesh, it would be delta based on what node needs)
    return jsonify({'status': 'ok', 'messages': message_store})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"Starting ResQNet Mesh Simulator on port {port}...")
    app.run(host='0.0.0.0', port=port)
