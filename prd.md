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
- [ ] Basic LiveView chat interface
- [x] Google OAuth implementation (Gmail + Calendar scopes)
- [x] HubSpot OAuth implementation
- [x] User authentication and session management

**Technical Requirements:**

- [x] Add dependencies: `ueberauth`, `ueberauth_google`, `pgvector`, `openai_ex`, `req`
- [x] Configure OAuth redirect URIs
- [x] Create user schema with OAuth token storage
- [ ] Basic chat LiveView with message input/display

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
  - [ ] `tasks`: JSON state storage, status tracking
  - [ ] `instructions`: Ongoing behavioral rules
  - [ ] `chat_messages`: Conversation history
- **API Integrations**:
  - [x] Gmail API client using stored OAuth tokens
  - [x] Google Calendar API client
  - [x] HubSpot API client (contacts, notes)
  - [x] OpenAI API client (chat completion, embeddings)
- [x] **Vector Search System**: Pgvector integration with cosine similarity search
- [x] **Content Chunk Schema**: Ecto schema with vector embedding support
- [x] **Vector Search Module**: Functions for embedding generation and similarity search
- [ ] **Background Jobs**: Oban jobs for data sync and embedding generation

### Phase 3: Core Agent Logic (Week 3)

**Deliverables:**

- [ ] LLM integration with tool calling
- [ ] RAG-powered question answering
- [ ] Task creation and basic execution
- [ ] Chat interface with context retrieval

**Technical Requirements:**

**Tool Definitions**:

- [ ] `send_email`: Compose and send emails via Gmail API
- [ ] `create_calendar_event`: Add events to Google Calendar
- [ ] `search_calendar`: Find calendar events and availability
- [ ] `create_hubspot_contact`: Add contacts to HubSpot
- [ ] `update_hubspot_contact`: Update existing contacts
- [ ] `search_data`: Vector search across all content chunks
- [ ] `search_gmail`: Find emails matching query
- [ ] `get_email_details`: Get full email with sender, recipients, etc.
- [ ] `search_contacts`: Find HubSpot contacts
- [ ] `get_contact_details`: Get contact info
- [ ] **LLM Function Calling**: OpenAI function calling with tool definitions
- [ ] **Context Retrieval**: Vector search to find relevant information for queries
- [ ] **Task Storage**: Create tasks from user requests and tool calls

### Phase 4: Task Orchestration (Week 4)

**Deliverables:**

- [ ] LLM-driven task management
- [ ] Multi-step workflow execution
- [ ] Task resumption on events
- [ ] Event-driven task processing

**Technical Requirements:**

- [ ] **Task Orchestration Logic**:

  ```elixir
  # Pseudo-code for task orchestration
  def process_event(event) do
    active_tasks = get_active_tasks()

    prompt = """
    Current active tasks: #{format_tasks(active_tasks)}
    New event: #{event}

    Which tasks should I work on? What actions should I take?
    Available tools: #{list_available_tools()}
    """

    llm_response = call_llm_with_tools(prompt)
    execute_actions(llm_response)
  end
  ```

- [ ] **Event Processing**: GenServer to handle incoming events
- [ ] **Task State Management**: Update task context and status based on LLM decisions
- [ ] **Tool Execution**: Execute LLM-requested actions and update task state

### Phase 5: Proactive Agent (Week 5)

**Deliverables:**

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

### Tasks _(Not Yet Implemented)_

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

### Instructions _(Not Yet Implemented)_

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

### Chat Messages _(Not Yet Implemented)_

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

### 🔄 **Phase 2: Remaining Items**

- Background jobs setup (Oban)
- Data synchronization system for ingesting content
- Chat interface LiveView

### 📋 **Phase 3-6: Not Yet Started**

- LLM tool calling system
- Task orchestration
- Proactive agent behavior
- UI polish and testing

## Success Criteria

- User can authenticate with Google and HubSpot
- Agent can answer questions about clients using RAG
- Agent can execute multi-step tasks autonomously
- Agent can handle ongoing instructions and proactive behavior
- Tasks can wait for responses and resume when events occur
- Simple, functional chat interface
- All integrations working with polling-based updates

## Constraints

- Interview project scope (simplified features)
- Free/low-cost services preferred
- Monolithic architecture
- No complex UI animations or styling initially
- Polling instead of webhooks for simplicity
