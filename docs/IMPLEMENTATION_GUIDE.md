# 🛠️ ResQNet V2: Step-by-Step Implementation Guide

## **PHASE 1: CORE INFRASTRUCTURE (Weeks 1-4)**

### Week 1: Project Setup & DevOps

**Goal**: Get deployable infrastructure running

```bash
# 1. Initialize FastAPI project
mkdir resqnet-v2-backend
cd resqnet-v2-backend
poetry init  # or pip + requirements.txt

# 2. Create project structure
mkdir -p app/{services,models,schemas,utils}
mkdir -p tests
mkdir -p k8s
mkdir -p scripts

# 3. Basic FastAPI app
# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="ResQNet V2", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "ok"}

# 4. Docker setup
# Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# 5. Docker Compose for local dev
# docker-compose.yml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/resqnet
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
      - mongo

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: resqnet
    volumes:
      - postgres_data:/var/lib/postgresql/data

  mongo:
    image: mongo:7
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7-alpine

volumes:
  postgres_data:
  mongo_data:

# 6. CI/CD setup
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pytest
      - run: flake8 app/

  docker-build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: docker/build-push-action@v4
        with:
          push: true
          tags: gcr.io/project/resqnet:${{ github.sha }}
```

**Checklist:**
- [ ] FastAPI project initialized
- [ ] Docker setup working (`docker-compose up`)
- [ ] CI/CD pipeline running
- [ ] Health endpoint returning 200

### Week 2: Backend Services v1

**Goal**: Build core API services

```python
# app/schemas/report.py
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime

class SeverityEnum(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    LOW = "LOW"

class ReportCreate(BaseModel):
    text: str
    latitude: float
    longitude: float
    image_url: Optional[str] = None
    audio_url: Optional[str] = None

class ReportResponse(BaseModel):
    id: str
    user_id: str
    text: str
    latitude: float
    longitude: float
    severity: SeverityEnum
    confidence_score: float
    created_at: datetime
    
    class Config:
        from_attributes = True

# app/services/report_service.py
from sqlalchemy.orm import Session
from app.models import Report
from app.schemas import ReportCreate, ReportResponse
import uuid
from datetime import datetime

class ReportService:
    @staticmethod
    async def create_report(
        db: Session,
        user_id: str,
        report_data: ReportCreate
    ) -> ReportResponse:
        report = Report(
            id=str(uuid.uuid4()),
            user_id=user_id,
            text=report_data.text,
            latitude=report_data.latitude,
            longitude=report_data.longitude,
            severity="PENDING",  # Will be updated by ML service
            confidence_score=0.0,
            created_at=datetime.utcnow()
        )
        db.add(report)
        db.commit()
        db.refresh(report)
        
        # Publish event
        await ReportService._publish_event("report.created", report.id)
        
        return ReportResponse.from_orm(report)
    
    @staticmethod
    async def get_report(db: Session, report_id: str):
        return db.query(Report).filter(Report.id == report_id).first()

# app/routes/reports.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.services.report_service import ReportService
from app.schemas import ReportCreate, ReportResponse
from app.database import get_db
from app.auth import get_current_user

router = APIRouter(prefix="/api/v2/reports", tags=["reports"])

@router.post("/submit", response_model=ReportResponse, status_code=201)
async def submit_report(
    report_data: ReportCreate,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Submit new disaster report"""
    try:
        report = await ReportService.create_report(
            db=db,
            user_id=current_user.id,
            report_data=report_data
        )
        return report
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/{report_id}", response_model=ReportResponse)
async def get_report(
    report_id: str,
    db: Session = Depends(get_db)
):
    """Get specific report"""
    report = await ReportService.get_report(db, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report

# app/main.py (updated)
from fastapi import FastAPI
from app.routes import reports, auth, messages
from app.middleware import logging_middleware

app = FastAPI(title="ResQNet V2", version="2.0.0")

# Include routers
app.include_router(reports.router)
app.include_router(auth.router)
app.include_router(messages.router)

@app.get("/health")
async def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow()}
```

**Checklist:**
- [ ] Report CRUD endpoints working
- [ ] Database models created and migrated
- [ ] Tests passing (50% coverage)
- [ ] API documentation accessible at `/docs`

### Week 3: ML Foundation

**Goal**: Set up inference serving

```python
# ml/bert_service.py
import torch
from transformers import DistilBertTokenizer, DistilBertForSequenceClassification
from typing import Tuple
import numpy as np

class BERTService:
    def __init__(self, model_path="distilbert-base-uncased"):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.tokenizer = DistilBertTokenizer.from_pretrained(model_path)
        self.model = DistilBertForSequenceClassification.from_pretrained(
            model_path,
            num_labels=3  # CRITICAL, HIGH, LOW
        ).to(self.device)
        self.model.eval()
        
        # Label mapping
        self.labels = {0: "LOW", 1: "HIGH", 2: "CRITICAL"}
    
    def predict(self, text: str) -> Tuple[str, float]:
        """
        Predict severity and confidence
        Returns: (severity, confidence_score)
        """
        # Tokenize
        inputs = self.tokenizer(
            text,
            return_tensors="pt",
            truncation=True,
            max_length=128,
            padding=True
        ).to(self.device)
        
        # Inference
        with torch.no_grad():
            outputs = self.model(**inputs)
            logits = outputs.logits
        
        # Get probabilities
        probs = torch.softmax(logits, dim=-1)[0].cpu().numpy()
        predicted_class = np.argmax(probs)
        confidence = float(probs[predicted_class])
        
        severity = self.labels[predicted_class]
        
        return severity, confidence
    
    def quantize(self):
        """Convert to int8 for 3.7x speedup"""
        self.model = torch.quantization.quantize_dynamic(
            self.model,
            {torch.nn.Linear},
            dtype=torch.qint8
        )

# ml/inference_service.py
from app.database import redis_client
from ml.bert_service import BERTService
import json
import time

class InferenceService:
    def __init__(self):
        self.bert_service = BERTService()
        self.bert_service.quantize()  # For production speed
    
    async def classify_report(self, report_id: str, text: str):
        """
        Classify report severity
        Publish result back to report service
        """
        try:
            # Inference
            severity, confidence = self.bert_service.predict(text)
            
            # Store result
            result = {
                "report_id": report_id,
                "severity": severity,
                "confidence_score": confidence,
                "timestamp": time.time()
            }
            
            # Publish event
            await redis_client.xadd(
                "report.classified",
                {"data": json.dumps(result)}
            )
            
            return result
        except Exception as e:
            print(f"Inference failed for {report_id}: {e}")
            raise

# ml/server.py (Ray Serve)
from ray import serve
from ml.inference_service import InferenceService

serve.start()

@serve.deployment
class MLPredictor:
    def __init__(self):
        self.service = InferenceService()
    
    async def predict(self, text: str) -> dict:
        return self.service.classify_report("", text)

predictor = MLPredictor.bind()
serve.run(predictor)
```

**Checklist:**
- [ ] BERT model downloaded and tested
- [ ] Quantization working (<100ms latency)
- [ ] Ray Serve or TF Serving running
- [ ] Integration test: report → ML → result

### Week 4: Mobile Integration

**Goal**: Connect Flutter app to backend

```dart
// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';

class ApiService {
  final String baseUrl = "https://api.resqnet.example.com/api/v2";
  String? _accessToken;
  
  Future<Map<String, dynamic>> submitReport({
    required String text,
    required double latitude,
    required double longitude,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reports/submit"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'text': text,
          'latitude': latitude,
          'longitude': longitude,
          'image_url': imageUrls?.first,
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to submit report: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("API Error: $e");
    }
  }
  
  Future<void> setAccessToken(String token) async {
    _accessToken = token;
  }
}

// lib/screens/submit_report_screen.dart
class SubmitReportScreen extends StatefulWidget {
  @override
  _SubmitReportScreenState createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _textController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  
  Future<void> _submitReport() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a description")),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final location = await _getCurrentLocation();
      
      final response = await _apiService.submitReport(
        text: _textController.text,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Report submitted! ID: ${response['id']}")),
      );
      
      _textController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Report Incident")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Describe the situation...",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text("Submit Report"),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Checklist:**
- [ ] Flutter app connects to API
- [ ] Report submission working end-to-end
- [ ] Location tracking implemented
- [ ] Error handling in place

---

## **PHASE 2: INTELLIGENCE LAYER (Weeks 5-8)**

### Week 5: BERT Fine-tuning

```python
# ml/training/train_bert.py
import torch
from transformers import DistilBertTokenizer, DistilBertForSequenceClassification, Trainer, TrainingArguments
from datasets import Dataset, DatasetDict
import pandas as pd
from sklearn.model_selection import train_test_split

class BERTTrainer:
    def __init__(self):
        self.model_name = "distilbert-base-uncased"
        self.tokenizer = DistilBertTokenizer.from_pretrained(self.model_name)
        self.labels_map = {"LOW": 0, "HIGH": 1, "CRITICAL": 2}
    
    def prepare_dataset(self, csv_path: str) -> DatasetDict:
        """Load and prepare labeled disaster data"""
        df = pd.read_csv(csv_path)
        
        # Split
        train_df, test_df = train_test_split(
            df, test_size=0.2, random_state=42, stratify=df['severity']
        )
        train_df, val_df = train_test_split(
            train_df, test_size=0.1, random_state=42, stratify=train_df['severity']
        )
        
        def process_function(examples):
            tokenized = self.tokenizer(
                examples['text'],
                truncation=True,
                max_length=128,
                padding=True
            )
            tokenized['labels'] = [
                self.labels_map[label] for label in examples['severity']
            ]
            return tokenized
        
        # Create datasets
        train_dataset = Dataset.from_pandas(train_df)
        val_dataset = Dataset.from_pandas(val_df)
        test_dataset = Dataset.from_pandas(test_df)
        
        # Tokenize
        train_dataset = train_dataset.map(process_function, batched=True)
        val_dataset = val_dataset.map(process_function, batched=True)
        test_dataset = test_dataset.map(process_function, batched=True)
        
        return DatasetDict({
            'train': train_dataset,
            'validation': val_dataset,
            'test': test_dataset
        })
    
    def train(self, dataset_dict: DatasetDict):
        """Fine-tune BERT"""
        model = DistilBertForSequenceClassification.from_pretrained(
            self.model_name,
            num_labels=3
        )
        
        training_args = TrainingArguments(
            output_dir="./results",
            num_train_epochs=5,
            per_device_train_batch_size=32,
            per_device_eval_batch_size=64,
            warmup_steps=500,
            weight_decay=0.01,
            logging_dir="./logs",
            logging_steps=10,
            eval_strategy="epoch",
            save_strategy="epoch",
            load_best_model_at_end=True,
        )
        
        trainer = Trainer(
            model=model,
            args=training_args,
            train_dataset=dataset_dict['train'],
            eval_dataset=dataset_dict['validation'],
        )
        
        # Train
        trainer.train()
        
        # Evaluate on test set
        eval_results = trainer.evaluate(dataset_dict['test'])
        print(f"Test Results: {eval_results}")
        
        # Save
        model.save_pretrained("./models/bert-disaster-classifier")
        self.tokenizer.save_pretrained("./models/bert-disaster-classifier")
        
        return model

# Usage
if __name__ == "__main__":
    trainer = BERTTrainer()
    datasets = trainer.prepare_dataset("labeled_disasters.csv")
    model = trainer.train(datasets)
```

### Week 6: Multimodal ML

```python
# ml/multimodal_model.py
import torch
import torch.nn as nn
from transformers import DistilBertModel, AutoModel
from torchvision.models import resnet50, ResNet50_Weights

class MultimodalDisasterClassifier(nn.Module):
    def __init__(self, num_labels=3):
        super().__init__()
        
        # Text branch: BERT
        self.bert = DistilBertModel.from_pretrained("distilbert-base-uncased")
        self.text_projection = nn.Linear(768, 256)
        
        # Image branch: ResNet50
        self.resnet = resnet50(weights=ResNet50_Weights.DEFAULT)
        self.resnet = nn.Sequential(*list(self.resnet.children())[:-1])
        self.image_projection = nn.Linear(2048, 256)
        
        # Geo branch
        self.geo_projection = nn.Linear(8, 64)
        
        # Fusion
        self.fusion = nn.Sequential(
            nn.Linear(256 + 256 + 64, 256),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(128, num_labels)
        )
    
    def forward(self, input_ids, attention_mask, images, geo_features):
        # Text
        text_out = self.bert(input_ids, attention_mask)[1]  # [CLS] token
        text_emb = self.text_projection(text_out)  # (batch, 256)
        
        # Image
        image_emb = self.resnet(images).squeeze(-1).squeeze(-1)  # (batch, 2048)
        image_emb = self.image_projection(image_emb)  # (batch, 256)
        
        # Geo
        geo_emb = self.geo_projection(geo_features)  # (batch, 64)
        
        # Concatenate
        combined = torch.cat([text_emb, image_emb, geo_emb], dim=-1)  # (batch, 576)
        
        # Classify
        logits = self.fusion(combined)
        
        return logits
```

### Weeks 7-8: Heatmap & Clustering

```python
# services/disaster_intelligence_service.py
import numpy as np
from sklearn.cluster import DBSCAN
from scipy.ndimage import gaussian_filter
from typing import List, Tuple
import geopandas as gpd

class DisasterIntelligenceService:
    def __init__(self):
        self.GRID_SIZE = 50  # 50x50 grid
        self.DBSCAN_EPS_KM = 1.0
        self.DBSCAN_MIN_PTS = 3
    
    def generate_heatmap(
        self,
        reports: List[dict],
        zone_bounds: Tuple[float, float, float, float]  # (min_lat, max_lat, min_lon, max_lon)
    ) -> np.ndarray:
        """Generate heatmap grid"""
        min_lat, max_lat, min_lon, max_lon = zone_bounds
        
        # Initialize grid
        grid = np.zeros((self.GRID_SIZE, self.GRID_SIZE))
        
        # Severity weights
        severity_weights = {"CRITICAL": 3, "HIGH": 1, "LOW": 0.3}
        
        # Fill grid
        for report in reports:
            lat, lng = report['latitude'], report['longitude']
            severity = report['severity']
            
            # Convert to grid coordinates
            grid_x = int((lat - min_lat) / (max_lat - min_lat) * self.GRID_SIZE)
            grid_y = int((lng - min_lon) / (max_lon - min_lon) * self.GRID_SIZE)
            
            # Clamp to grid
            grid_x = max(0, min(self.GRID_SIZE - 1, grid_x))
            grid_y = max(0, min(self.GRID_SIZE - 1, grid_y))
            
            # Add weight
            grid[grid_x, grid_y] += severity_weights.get(severity, 0)
        
        # Gaussian smoothing
        smoothed = gaussian_filter(grid, sigma=1)
        
        # Normalize
        if smoothed.max() > 0:
            smoothed = smoothed / smoothed.max()
        
        return smoothed
    
    def cluster_reports(self, reports: List[dict]) -> List[dict]:
        """DBSCAN clustering"""
        if not reports:
            return []
        
        # Extract coordinates
        coords = np.array([[r['latitude'], r['longitude']] for r in reports])
        
        # DBSCAN (using haversine for lat/lng)
        clustering = DBSCAN(
            eps=self.DBSCAN_EPS_KM / 111,  # Convert km to degrees
            min_samples=self.DBSCAN_MIN_PTS,
            metric='haversine'
        ).fit(np.radians(coords))
        
        labels = clustering.labels_
        
        # Group by cluster
        clusters = {}
        for idx, label in enumerate(labels):
            if label == -1:
                continue  # Skip noise
            if label not in clusters:
                clusters[label] = []
            clusters[label].append(reports[idx])
        
        # Compute cluster centroids
        result = []
        for cluster_id, cluster_reports in clusters.items():
            lats = [r['latitude'] for r in cluster_reports]
            lngs = [r['longitude'] for r in cluster_reports]
            
            result.append({
                'cluster_id': cluster_id,
                'center_lat': np.mean(lats),
                'center_lng': np.mean(lngs),
                'report_count': len(cluster_reports),
                'reports': cluster_reports
            })
        
        return result
```

---

## **PHASE 3: REAL-TIME SYSTEMS (Weeks 9-12)**

### Week 9: WebSocket Setup

```python
# app/routes/ws.py
from fastapi import WebSocket, WebSocketDisconnect
from typing import Set
import json
import asyncio

class ConnectionManager:
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()
        self.subscriptions: dict = {}  # user_id → set of channels
    
    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        self.active_connections.add(websocket)
        if user_id not in self.subscriptions:
            self.subscriptions[user_id] = set()
    
    async def disconnect(self, websocket: WebSocket, user_id: str):
        self.active_connections.discard(websocket)
    
    async def broadcast_to_zone(self, zone_id: str, message: dict):
        """Broadcast to all users in zone"""
        for user_id, channels in self.subscriptions.items():
            if f"zone:{zone_id}" in channels:
                # Find websocket for user_id and send
                for ws in self.active_connections:
                    try:
                        await ws.send_json({
                            "channel": f"zone:{zone_id}",
                            **message
                        })
                    except:
                        pass

manager = ConnectionManager()

@app.websocket("/api/v2/stream/disaster-updates")
async def websocket_endpoint(websocket: WebSocket, token: str):
    user = await get_current_user_ws(token)
    await manager.connect(websocket, user.id)
    
    try:
        while True:
            # Receive subscription requests
            data = await websocket.receive_json()
            
            if data.get("action") == "subscribe":
                channel = data.get("channel")
                manager.subscriptions[user.id].add(channel)
            elif data.get("action") == "unsubscribe":
                channel = data.get("channel")
                manager.subscriptions[user.id].discard(channel)
    
    except WebSocketDisconnect:
        await manager.disconnect(websocket, user.id)

# Usage in services
async def publish_heatmap_update(zone_id: str, grid: np.ndarray):
    await manager.broadcast_to_zone(zone_id, {
        "event_type": "heatmap_update",
        "data": {
            "grid": grid.tolist(),
            "timestamp": datetime.utcnow().isoformat()
        }
    })
```

### Weeks 10-12: Event-Driven System

```python
# services/event_service.py
import aioredis
import json
from typing import Callable

class EventService:
    def __init__(self, redis_url: str):
        self.redis = None
        self.redis_url = redis_url
        self.consumers = {}
    
    async def initialize(self):
        self.redis = await aioredis.from_url(self.redis_url)
    
    async def publish(self, stream: str, data: dict):
        """Publish event to stream"""
        await self.redis.xadd(stream, {"data": json.dumps(data)})
    
    async def subscribe(self, stream: str, handler: Callable):
        """Subscribe to stream"""
        self.consumers[stream] = handler
        last_id = "0"
        
        while True:
            messages = await self.redis.xread(
                {stream: last_id},
                block=0
            )
            
            for msg_stream, msg_id, msg_data in messages:
                data = json.loads(msg_data[b'data'])
                await handler(data)
                last_id = msg_id

# Usage
event_service = EventService("redis://localhost:6379")

# Consumer: ML Classification
async def classify_report_handler(data: dict):
    report_id = data['report_id']
    text = data['text']
    
    severity, confidence = ml_service.classify(text)
    
    await event_service.publish("report.classified", {
        "report_id": report_id,
        "severity": severity,
        "confidence_score": confidence
    })

# Consumer: Heatmap Generation
async def generate_heatmap_handler(data: dict):
    report_id = data['report_id']
    zone_id = data['zone_id']
    
    # Get all reports in zone
    reports = db.query(Report).filter(Report.zone_id == zone_id).all()
    
    # Generate heatmap
    heatmap = intelligence_service.generate_heatmap(reports, zone_bounds)
    
    # Publish
    await event_service.publish("heatmap.updated", {
        "zone_id": zone_id,
        "grid": heatmap.tolist()
    })
    
    # Broadcast to WebSocket clients
    await manager.broadcast_to_zone(zone_id, {
        "event_type": "heatmap_update",
        "data": {"grid": heatmap.tolist()}
    })

# Main startup
@app.on_event("startup")
async def startup():
    await event_service.initialize()
    
    # Start consumers
    asyncio.create_task(
        event_service.subscribe("report.created", classify_report_handler)
    )
    asyncio.create_task(
        event_service.subscribe("report.classified", generate_heatmap_handler)
    )
```

---

## **QUICK START: Local Development**

```bash
# Clone repo
git clone https://github.com/snehal1931/ResQNet.git
cd ResQNet/backend

# Setup virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start databases
docker-compose up -d

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload

# In another terminal, start ML service
python ml/inference_service.py

# In another terminal, start event consumers
python ml/consumers.py

# API available at http://localhost:8000
# Docs at http://localhost:8000/docs
```

---

**Total estimated time: 20 weeks (with 3-5 person team)**
