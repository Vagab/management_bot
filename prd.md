AI Financial Advisor Agent - Product Requirements Document

## Project Overview

Build an AI agent for Financial Advisors that integrates with Gmail, Google Calendar, and HubSpot CRM. The agent provides a ChatGPT-like interface for answering questions about clients and executing tasks autonomously using RAG (Retrieval Augmented Generation) and LLM tool calling.

## Technical Stack

- **Backend**: Elixir Phoenix with LiveView
- **Database**: PostgreSQL with pgvector extension
- **LLM**: OpenAI GPT-3.5-turbo/GPT-4o-mini with function calling
- **Authentication**: OAuth 2.0 (Google, HubSpot)
- **Architecture**: Monolithic with LLM-driven task orchestration

## Core Features

### 1. Authentication & Authorization

- Google OAuth with Gmail read/write and Calendar read/write permissions
- HubSpot OAuth integration (custom implementation)
- Test user: webshookeng@gmail.com
- Session management for multi-platform OAuth tokens

### 2. Data Integration & RAG System

- **Gmail Integration**: Fetch all emails, extract content, generate embeddings
- **Google Calendar Integration**: Access calendar events and availability
- **HubSpot Integration**: Sync contacts, notes, and CRM data
- **Vector Search**: Use pgvector for semantic search across all integrated data
- **Embeddings**: OpenAI text-embedding-3-small for cost efficiency

### 3. Chat Interface

- Simple, clean chat UI (basic styling, rounded borders)
- Real-time updates via Phoenix LiveView
- Context-aware responses using RAG
- Examples of supported queries:
  - "Who mentioned their kid plays baseball?"
  - "Why did Greg say he wanted to sell AAPL stock?"

### 4. Task Management System

- **LLM-driven orchestration**: Instead of hardcoded workflows, use LLM to manage task state and decide next actions
- **Persistent tasks**: Store tasks in database with JSON context
- **Multi-step workflows**: Tasks can wait for responses and resume when events occur
- **Example workflow**: "Schedule appointment with Sara Smith"
  1. Look up Sara's contact
  2. Check calendar availability
  3. Send email with available times
  4. Wait for response (task goes dormant)
  5. Parse response and take appropriate action
  6. Continue until completion

### 5. Proactive Agent Behavior

- **Ongoing Instructions**: Persistent behavioral rules that trigger on events
- **Event Processing**: Polling-based system for Gmail, Calendar, and HubSpot changes
- **Automatic Task Creation**: Instructions can spawn new tasks when triggered
- **Examples**:
  - "When someone emails me that's not in HubSpot, create a contact"
  - "When I create a contact, send them a welcome email"
  - "When I add a calendar event, email attendees about the meeting"

## Implementation Phases

### Phase 1: Foundation & Auth (Week 1)

**Deliverables:**

- [x] Phoenix app configured with required dependencies
- [x] PostgreSQL with pgvector extension
- [x] Basic LiveView chat interface
- [x] Google OAuth implementation (Gmail + Calendar scopes)
- [x] HubSpot OAuth implementation
- [x] User authentication and session management

**Technical Requirements:**

- [x] Add dependencies: `ueberauth`, `ueberauth_google`, `pgvector`, `openai_ex`, `req`
- [x] Configure OAuth redirect URIs
- [x] Create user schema with OAuth token storage
- [x] Basic chat LiveView with message input/display

### Phase 2: Data Integration & RAG (Week 2)

**Deliverables:**

- [x] Database schemas for all entities
- [x] API clients for Gmail, Calendar, HubSpot
- [ ] Data synchronization system
- [x] Vector embedding and search functionality

**Technical Requirements:**

- **Database Tables**:
  - [x] `users`: OAuth tokens, settings
  - [x] `content_chunks`: All content (emails, contacts, calendar) with embeddings
  - [x] `tasks`: JSONB context storage, status tracking, user associations
  - [x] `instructions`: Ongoing behavioral rules with user associations
  - [x] `chat_messages`: Conversation history with user associations
- **API Integrations**:
  - [x] Gmail API client using stored OAuth tokens
  - [x] Google Calendar API client
  - [x] HubSpot API client (contacts, notes)
  - [x] OpenAI API client (chat completion, embeddings)
- [x] **Vector Search System**: Pgvector integration with cosine similarity search
- [x] **Content Chunk Schema**: Ecto schema with vector embedding support
- [x] **Vector Search Module**: Functions for embedding generation and similarity search
- [x] **Task Management System**: Schema with JSONB context for LLM execution traces
- [x] **Instructions System**: Simple behavioral rules with user scoping
- [x] **Chat System**: Message history with role-based conversation tracking
- [x] **Phoenix Contexts**: Simplified, user-scoped context modules for all entities
- [ ] **Background Jobs**: Oban jobs for data sync and embedding generation

### Phase 3: Core Agent Logic (Week 3)

**Deliverables:**

- [x] LLM integration with tool calling
- [x] RAG-powered question answering
- [x] Task creation and basic execution
- [x] Chat interface with context retrieval

**Technical Requirements:**

**Tool Definitions**:

- [x] `send_email`: Compose and send emails via Gmail API
- [x] `create_calendar_event`: Add events to Google Calendar
- [x] `search_calendar`: Find calendar events and availability
- [x] `create_hubspot_contact`: Add contacts to HubSpot (via search_contacts)
- [x] `update_hubspot_contact`: Update existing contacts (via search_contacts)
- [x] `search_data`: Vector search across content chunks
- [x] `search_gmail`: Find emails matching query (via get_email_details)
- [x] `get_email_details`: Get full email with sender, recipients, etc.
- [x] `search_contacts`: Find HubSpot contacts
- [x] `get_contact_details`: Get contact info (via search_contacts)
- [x] **LLM Function Calling**: OpenAI function calling with tool definitions
- [x] **Context Retrieval**: Vector search to find relevant information for queries
- [x] **LLM Module**: Chat interface with RAG + tool calling integration
- [x] **Tools Module**: Tool execution and response formatting
- [x] **Task Storage**: Create tasks from user requests and tool calls

### ✅ **Phase 4: Task Orchestration (COMPLETE)**

**Deliverables:**

- [x] LLM-driven task management
- [x] Multi-step workflow execution
- [x] Task resumption on events
- [x] Event-driven task processing

**Technical Requirements:**

- [x] **Task Orchestration Logic**: Cron-based orchestrator using LLM.process_with_tools for recursive tool calling
- [x] **Event Processing**: Hourly cron job processes all users and collects new emails, active tasks
- [x] **Task State Management**: Update task context and status based on LLM decisions
- [x] **Tool Execution**: Execute LLM-requested actions and update task state
- [x] **Task Creation Tool**: `create_task` tool for workflows that cannot be completed immediately
- [x] **Task Management Tools**: `update_task_status` and `update_task_context` tools
- [x] **Recursive Tool Calling**: Reuses LLM.chat recursive logic for up to 5 iterations
- [x] **Oban Background Jobs**: Configured with cron plugin for automated task orchestration
- [x] **Enhanced Prompts**: Clear guidance for LLM on task completion and status management

### Phase 5: Proactive Agent (Week 5)

**Deliverables:**

- [ ] Improve RAG system. It doesn't really seem to work I think? Maybe test first
- [ ] Polling system for external APIs
- [ ] Instruction processing system
- [ ] Automated task creation from instructions
- [ ] Event-driven proactive behavior

**Technical Requirements:**

- **Polling System**:
  - [ ] Gmail polling for new emails
  - [ ] Calendar polling for event changes
  - [ ] HubSpot polling for contact updates
  - [ ] Configurable polling intervals
- **Instruction Processing**:
  - [ ] Store ongoing instructions in database
  - [ ] Evaluate instructions against incoming events
  - [ ] Create new tasks when instructions are triggered
- **Proactive Behavior**:
  - [ ] LLM evaluation of events against instructions
  - [ ] Automatic task spawning
  - [ ] Notification system for user awareness

### Phase 6: Polish & Testing (Week 6)

**Deliverables:**

- [ ] UI improvements (responsive design, better styling)
- [ ] Error handling and edge cases
- [ ] Performance optimization
- [ ] Testing and bug fixes

**Technical Requirements:**

- [ ] Enhanced LiveView UI with better UX
- [ ] Comprehensive error handling
- [ ] Rate limiting for API calls
- [ ] Task timeout and cleanup mechanisms
- [ ] Integration testing

## Database Schema

### Users

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR NOT NULL,
  google_access_token TEXT,
  google_refresh_token TEXT,
  hubspot_access_token TEXT,
  hubspot_refresh_token TEXT,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Content Chunks

```sql
CREATE TABLE content_chunks (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  source VARCHAR NOT NULL, -- 'gmail', 'hubspot', 'calendar'
  embedding VECTOR(1536),
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- Indexes for performance
CREATE INDEX content_chunks_user_id_index ON content_chunks (user_id);
CREATE INDEX content_chunks_source_index ON content_chunks (source);
CREATE INDEX content_chunks_user_id_source_index ON content_chunks (user_id, source);

-- Vector similarity search index using HNSW algorithm
CREATE INDEX content_chunks_embedding_idx ON content_chunks USING hnsw (embedding vector_cosine_ops);
```

### Tasks

```sql
CREATE TABLE tasks (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  status VARCHAR DEFAULT 'in_progress',
  context JSONB,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Instructions

```sql
CREATE TABLE instructions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  inserted_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Chat Messages

```sql
CREATE TABLE chat_messages (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR NOT NULL, -- 'user' or 'assistant'
  content TEXT NOT NULL,
  inserted_at TIMESTAMP
);
```

## API Specifications

### Tool Calling Functions

1. **send_email**
   - Parameters: recipient, subject, body
   - Action: Send email via Gmail API
   - Return: Success/failure status

2. **create_calendar_event**
   - Parameters: title, start_time, end_time, attendees, description
   - Action: Create Google Calendar event
   - Return: Event ID and confirmation

3. **search_calendar**
   - Parameters: date_range, keyword (optional)
   - Action: Search calendar for events and availability
   - Return: List of events and free time slots

4. **create_hubspot_contact**
   - Parameters: email, first_name, last_name, company, notes
   - Action: Create contact in HubSpot
   - Return: Contact ID and confirmation

5. **search_data**
   - Parameters: query, source_filter (gmail, hubspot, calendar, all)
   - Action: Vector search across content chunks
   - Return: Relevant information with sources

6. **search_gmail**
   - Parameters: query, limit (optional)
   - Action: Search Gmail for emails matching query
   - Return: List of emails with structured data

7. **get_email_details**
   - Parameters: email_id
   - Action: Get full email details from Gmail API
   - Return: Complete email with sender, recipients, body, etc.

8. **search_contacts**
   - Parameters: query, limit (optional)
   - Action: Search HubSpot contacts
   - Return: List of contacts with structured data

9. **get_contact_details**
   - Parameters: contact_id
   - Action: Get full contact details from HubSpot API
   - Return: Complete contact information

## Implementation Status

### ✅ **Phase 1: Foundation & Auth (COMPLETE)**

- Phoenix app with required dependencies
- PostgreSQL with pgvector extension
- Google OAuth (Gmail + Calendar scopes)
- HubSpot OAuth implementation
- User authentication and session management

### ✅ **Phase 2: Data Integration & RAG (COMPLETE)**

- Content chunks database schema with vector support
- Pgvector integration with PostgrexTypes
- HNSW indexing for efficient similarity search
- ContentChunk Ecto schema with embeddings
- VectorSearch module with OpenAI integration
- Vector storage, retrieval, and similarity search working
- Tasks schema with JSONB context for LLM execution traces
- Instructions schema for behavioral rules
- Chat messages schema for conversation history
- Phoenix contexts with user-scoped operations

### ✅ **Phase 3: Core Agent Logic (COMPLETE)**

- LLM integration with gpt-4o-mini model
- Tool calling system with 12 core tools (search_gmail, get_email_details, send_email, search_contacts, get_contact_details, create_hubspot_contact, update_hubspot_contact, search_calendar, create_calendar_event, search_data, create_task, update_task_status, update_task_context)
- RAG-powered question answering with automatic context
- Conversation history management
- Tool execution with error handling and response formatting
- **Chat Interface**: Full LiveView implementation with real-time updates
- **Recursive Tool Calling**: Up to 5 iterations with full conversation context preservation
- **Progress Updates**: PubSub-based progress indicators during tool execution
- **Enhanced UI**: Message deletion, auto-scroll, improved styling
- **Structured Logging**: Comprehensive logging throughout LLM pipeline
- **Async Processing**: Non-blocking LLM processing with PubSub notifications

### 🔄 **Phase 2: Remaining Items**

- Background jobs setup (Oban)
- Data synchronization system for ingesting content

### ✅ **Phase 3: Core Agent Logic (COMPLETE)**

- LLM integration with gpt-4o-mini model
- Tool calling system with 9 core tools
- RAG-powered question answering with automatic context
- Conversation history management
- Tool execution with error handling and response formatting
- **NEW**: Chat interface LiveView with real-time updates
- **NEW**: Recursive tool calling (up to 5 iterations) with full context preservation
- **NEW**: PubSub progress updates showing tool execution status
- **NEW**: Message deletion functionality
- **NEW**: Auto-scroll to bottom for new messages
- **NEW**: Structured logging throughout LLM pipeline
- **NEW**: Improved UI with better spacing, colors, and responsive design

### ✅ **Phase 4: Task Orchestration (COMPLETE)**

**Deliverables:**

- [x] LLM-driven task management
- [x] Multi-step workflow execution
- [x] Task resumption on events
- [x] Event-driven task processing

**Technical Requirements:**

- [x] **Task Creation**: `create_task` tool automatically creates tasks from user requests
- [x] **Task Orchestration Logic**: Cron-based LLM-driven task state management
- [x] **Event Processing**: Hourly orchestration with email polling and context collection
- [x] **Task State Management**: `update_task_status` and `update_task_context` tools
- [x] **Tool Execution**: Recursive tool calling with full context preservation
- [x] **Oban Integration**: Background job processing with cron scheduling
- [x] **Task Completion**: Enhanced prompts ensure tasks are properly marked complete

### 📋 **Phase 5-6: Future Work**

- Proactive agent behavior
- Instructions processing
- Background data synchronization
- UI polish and testing

## Technical Architecture Decisions

### **Database Design**

- **Unified Content Chunks**: All content (emails, contacts, calendar) stored in single table for semantic search
- **JSONB Context**: Task context uses flexible JSONB for LLM-driven execution traces
- **User Scoping**: All entities properly scoped to users with foreign key constraints
- **Vector Search**: PostgreSQL pgvector with HNSW indexing for production-scale similarity search

### **LLM-Driven Task Management**

- **Dynamic Context**: Task context stores full execution history including tool calls and reasoning
- **Flexible Structure**: No predefined workflow - LLM decides what steps to take based on context
- **Resumable Tasks**: Tasks can pause and resume by examining their execution history
- **Self-Documenting**: Full audit trail of LLM reasoning and actions

### **Security & Isolation**

- **User-Scoped Operations**: All database operations filtered by user_id
- **CASCADE Deletes**: Clean up all user data when user is deleted
- **OAuth Integration**: Secure token management for external APIs

### **Performance Optimizations**

- **Strategic Indexing**: Indexes on user_id, status, timestamps, and vector similarity
- **HNSW Vector Index**: Approximate nearest neighbor search for fast embedding queries
- **Enum Types**: Ecto enums for type safety and performance

### **LLM Integration**

- **Hybrid RAG Approach**: Automatic context retrieval + tool-based deeper search
- **Function Calling**: Native OpenAI tool calling with structured parameters
- **Tool Ecosystem**: 12 integrated tools covering email, calendar, contacts, search, and task management
- **Conversation Management**: Persistent chat history with context awareness
- **Recursive Tool Calling**: Up to 5 iterations with full conversation context preservation
- **Progress Tracking**: Real-time progress updates via PubSub during tool execution
- **Structured Logging**: Comprehensive logging of LLM interactions and tool execution
- **Error Handling**: Graceful fallbacks and tool execution error management
- **Async Processing**: Non-blocking LLM processing with PubSub-based UI updates

## Success Criteria

- [x] User can authenticate with Google and HubSpot
- [x] Agent can answer questions about clients using RAG
- [x] Agent can execute multi-step tasks autonomously
- [x] Agent can create, manage, and complete tasks automatically
- [x] Tasks can be resumed and processed based on events (emails, time)
- [x] Simple, functional chat interface with real-time updates
- [ ] Agent can handle ongoing instructions and proactive behavior (Phase 5)
- [x] Task orchestration working with cron-based polling

## Constraints

- Interview project scope (simplified features)
- Free/low-cost services preferred
- Monolithic architecture
- No complex UI animations or styling initially
- Polling instead of webhooks for simplicity
