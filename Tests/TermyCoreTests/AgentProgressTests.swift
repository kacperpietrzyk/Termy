import XCTest
@testable import TermyCore

final class AgentProgressTests: XCTestCase {
    private func decode(_ json: String) throws -> AgentToolEvent {
        try JSONDecoder().decode(AgentToolEvent.self, from: Data(json.utf8))
    }

    func testDecodesTaskCreatePayload() throws {
        let event = try decode("""
        {"hook_event_name":"PostToolUse","tool_name":"TaskCreate",
         "tool_input":{"subject":"Write failing test","description":"...","activeForm":"writing test"},
         "tool_response":{"task":{"id":"task_1","subject":"Write failing test"}}}
        """)
        XCTAssertEqual(event.toolName, "TaskCreate")
        XCTAssertEqual(event.input.subject, "Write failing test")
        XCTAssertEqual(event.input.activeForm, "writing test")
        XCTAssertEqual(event.response?.task?.id, "task_1")
    }

    func testDecodesTaskUpdatePayload() throws {
        let event = try decode("""
        {"tool_name":"TaskUpdate","tool_input":{"taskId":"task_1","status":"completed"}}
        """)
        XCTAssertEqual(event.toolName, "TaskUpdate")
        XCTAssertEqual(event.input.taskId, "task_1")
        XCTAssertEqual(event.input.status, "completed")
        XCTAssertNil(event.response)
    }

    func testDecodesEditPayloadFilePath() throws {
        let event = try decode("""
        {"tool_name":"Edit","tool_input":{"file_path":"/repo/A.swift","old_string":"x","new_string":"y"}}
        """)
        XCTAssertEqual(event.toolName, "Edit")
        XCTAssertEqual(event.input.filePath, "/repo/A.swift")
    }

    // Real transcripts show TaskCreate's result rendered as a string ("Task #1
    // created successfully: ..."). The hook's tool_response shape is unverified,
    // so a string (or any non-object) tool_response must NOT make decoding throw
    // — the TaskCreate event must still decode (response just becomes nil).
    func testStringOrOddToolResponseDoesNotBreakDecode() throws {
        let s = try decode("""
        {"tool_name":"TaskCreate","tool_input":{"subject":"A"},"tool_response":"Task #1 created successfully"}
        """)
        XCTAssertEqual(s.toolName, "TaskCreate")
        XCTAssertEqual(s.input.subject, "A")
        XCTAssertNil(s.response)
        // A well-formed-but-irrelevant object response (Edit/Write) also decodes fine.
        let w = try decode(#"{"tool_name":"Write","tool_input":{"file_path":"/x"},"tool_response":{"filePath":"/x","success":true}}"#)
        XCTAssertEqual(w.input.filePath, "/x")
        XCTAssertNil(w.response?.task?.id)
    }

    func testEmptyProgressHasNoPlanOrTouched() {
        XCTAssertEqual(AgentProgress.empty.plan, [])
        XCTAssertEqual(AgentProgress.empty.touched, [])
    }

    private func event(_ tool: String, taskId: String? = nil, status: String? = nil,
                       subject: String? = nil, activeForm: String? = nil,
                       filePath: String? = nil, responseId: String? = nil) -> AgentToolEvent {
        let input = AgentToolEvent.Input(
            taskId: taskId, status: status, subject: subject,
            activeForm: activeForm, filePath: filePath)
        let response = responseId.map {
            AgentToolEvent.Response(task: AgentToolEvent.Response.Task(id: $0)) }
        return AgentToolEvent(toolName: tool, input: input, response: response)
    }

    func testTaskCreateAppendsTodoStep() {
        let p = reduceAgentProgress(.empty,
            applying: event("TaskCreate", subject: "Step A", activeForm: "doing A", responseId: "t1"))
        XCTAssertEqual(p.plan.count, 1)
        XCTAssertEqual(p.plan[0].id, "t1")
        XCTAssertEqual(p.plan[0].text, "Step A")
        XCTAssertEqual(p.plan[0].state, .todo)
        XCTAssertEqual(p.plan[0].sub, "doing A")
    }

    func testTaskCreateWithoutResponseIdUsesSequentialOrdinal() {
        // Mirrors the observed scheme: ids "1","2",... in creation order, so a
        // later TaskUpdate(taskId:"2") matches even when the hook gave no task.id.
        var p = reduceAgentProgress(.empty, applying: event("TaskCreate", subject: "A"))
        p = reduceAgentProgress(p, applying: event("TaskCreate", subject: "B"))
        XCTAssertEqual(p.plan.map(\.id), ["1", "2"])
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "2", status: "in_progress"))
        XCTAssertEqual(p.plan[1].state, .active)
    }

    func testTaskUpdateTransitionsState() {
        var p = reduceAgentProgress(.empty, applying: event("TaskCreate", subject: "A", responseId: "t1"))
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "t1", status: "in_progress"))
        XCTAssertEqual(p.plan[0].state, .active)
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "t1", status: "completed"))
        XCTAssertEqual(p.plan[0].state, .done)
    }

    func testTaskUpdateDeletedRemovesStep() {
        var p = reduceAgentProgress(.empty, applying: event("TaskCreate", subject: "A", responseId: "t1"))
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "t1", status: "deleted"))
        XCTAssertTrue(p.plan.isEmpty)
    }

    func testTaskUpdateUnknownIdIsNoop() {
        let p = reduceAgentProgress(.empty, applying: event("TaskUpdate", taskId: "ghost", status: "done"))
        XCTAssertTrue(p.plan.isEmpty)
    }

    func testEditWriteMultiEditDedupTouched() {
        var p = reduceAgentProgress(.empty, applying: event("Edit", filePath: "/a"))
        p = reduceAgentProgress(p, applying: event("Write", filePath: "/b"))
        p = reduceAgentProgress(p, applying: event("MultiEdit", filePath: "/a"))   // dup
        XCTAssertEqual(p.touched, ["/a", "/b"])
    }

    func testFullSequenceReconstructsStepper() {
        var p = AgentProgress.empty
        p = reduceAgentProgress(p, applying: event("TaskCreate", subject: "read", responseId: "t1"))
        p = reduceAgentProgress(p, applying: event("TaskCreate", subject: "impl", responseId: "t2"))
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "t1", status: "completed"))
        p = reduceAgentProgress(p, applying: event("TaskUpdate", taskId: "t2", status: "in_progress"))
        XCTAssertEqual(p.plan.map(\.state), [.done, .active])
        XCTAssertEqual(p.plan.map(\.text), ["read", "impl"])
    }

    func testUnknownToolIsNoop() {
        let p = reduceAgentProgress(.empty, applying: event("Bash", filePath: nil))
        XCTAssertEqual(p, .empty)
    }
}
