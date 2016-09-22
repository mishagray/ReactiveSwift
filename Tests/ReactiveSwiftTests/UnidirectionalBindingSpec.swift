import Result
import Nimble
import Quick
@testable import ReactiveSwift

class UnidirectionalBindingSpec: QuickSpec {
	override func spec() {
		describe("AnyBindingTarget") {
			var token: Lifetime.Token!
			var lifetime: Lifetime!
			var target: AnyBindingTarget<Int>!
			var value: Int!

			beforeEach {
				token = Lifetime.Token()
				lifetime = Lifetime(token)
				target = AnyBindingTarget(setter: { value = $0 }, lifetime: lifetime)
				value = nil
			}

			it("should pass through the lifetime") {
				expect(target.lifetime).to(beIdenticalTo(lifetime))
			}

			it("should trigger the supplied setter") {
				expect(value).to(beNil())

				target.consume(1)
				expect(value) == 1
			}

			it("should accept bindings from properties") {
				expect(value).to(beNil())

				let property = MutableProperty(1)
				target <~ property
				expect(value) == 1

				property.value = 2
				expect(value) == 2
			}

			it("should not deadlock on the main queue") {
				target = AnyBindingTarget(mainQueueSetter: { value = $0 },
				                          lifetime: lifetime)

				let property = MutableProperty(1)
				target <~ property
				expect(value) == 1
			}

			it("should not deadlock even if the value is originated from the main queue indirectly") {
				let key = DispatchSpecificKey<Void>()
				DispatchQueue.main.setSpecific(key: key, value: ())

				let mainQueueCounter = Atomic(0)

				let setter: (Int) -> Void = {
					value = $0
					mainQueueCounter.modify { $0 += DispatchQueue.getSpecific(key: key) != nil ? 1 : 0 }
				}

				target = AnyBindingTarget(mainQueueSetter: setter,
				                          lifetime: lifetime)

				let scheduler: QueueScheduler
				if #available(OSX 10.10, *) {
					scheduler = QueueScheduler()
				} else {
					scheduler = QueueScheduler(queue: DispatchQueue(label: "com.reactivecocoa.ReactiveSwift.UnidirectionalBindingSpec"))
				}

				let property = MutableProperty(1)
				target <~ property.producer
					.start(on: scheduler)
					.observe(on: scheduler)

				expect(value).toEventually(equal(1))
				expect(mainQueueCounter.value).toEventually(equal(1))

				property.value = 2
				expect(value).toEventually(equal(2))
				expect(mainQueueCounter.value).toEventually(equal(2))
			}
		}
	}
}
