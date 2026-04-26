from flask import Flask, request, jsonify
import uuid
import time

app = Flask(__name__)

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
    message_id = data.get('message_id')
    new_status = data.get('status', 'PENDING')
    
    if not message_id:
        return jsonify({'status': 'error', 'message': 'Missing message_id'}), 400
        
    # Find if message exists to update it
    existing_msg = next((m for m in message_store if m.get('message_id') == message_id), None)
    
    if existing_msg:
        if existing_msg.get('status') != new_status:
            existing_msg['status'] = new_status
            return jsonify({'status': 'updated', 'message_id': message_id, 'new_status': new_status})
        return jsonify({'status': 'ignored', 'message': 'Message already seen with same status'})
        
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
    print("Starting ResQNet Mesh Simulator on port 5000...")
    app.run(host='0.0.0.0', port=5000)
