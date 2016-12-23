# SKBatcher

Batch loading content for UITableView or other progressively-loading controllers.

1. [What can this do to help me?](#what)
2. [Requirements](#reqs)
3. [Integration](#integration)
4. [Usage](#usage)
5. [Status and Next Steps](#status)

## What can this do to help me?

Probably easiest to go through an example. In the [AngelList Jobs App](https://angel.co/jobs_app), we have a messaging feature that allows job seekers to communicate with candidate seekers. It's a pretty standard chat UI -- you see a list of your conversations in a `UITableView` and you can tap on one to view the chat messages:

![Chat UI](https://github.com/klep/SKBatcher/raw/master/images/message_list.png)

Loading the list is tricky. The user could have thousands of conversations. Obtaining the avatar of the other user and the excerpt of the most recent message are expensive operations. We want the table to load and scroll as quickly as possible, but we don't want to send massive payloads back from our server that we might not even need.

SKBatcher makes it super easy to load portions of the view more efficiently. Since UITableView has the smarts to load cells only when they're needed, we can hit our server only when needed. In our case, the list of conversations is obtained in a single query, but the excerpt and avatar come in the background, only when needed. SKBatcher handles:

1. Loading the ancillary data for a conversation when iOS tells us it's needed for display

2. Batching together requests so that we don't flood our server with tons of tiny requests.

3. Keeping track of outstanding requests so that we don't waste time on duplicate requests.

4. Caching results so that if a user scrolls down then up, we don't hit the server again.

## Requirements

- iOS 8.0+
- Xcode 8
- Swift 2.3

Dependencies:

- `SwiftyJSON ~> 2.3.3`

## Integration

#### CocoaPods

You can use [CocoaPods](http://cocoapods.org/) to install `SKBatcher` by adding it to your `Podfile`:

```ruby
platform :ios, '9.0'
use_frameworks!

target 'MyApp' do
    pod 'SKBatcher'
end
```

## Usage

1. Create a function that your SKBatcher will use

You'll need a function that SKBatcher can use to obtain results for a list of IDs. This is *probably* a server call that looks something like this example, which uses Alamofire, but it can be anything as long as it conforms to the expected function signature:

```swift
    func getConversationExcerpts(ids: [Int], completion: (JSON?) -> Void) {
        request("GET", path: "/excerpts", parameters: ["ids": ids], encoding: .URL).responseData { response in
            if let results = response.result.value {
                completion(JSON(data: results))
            } else {
                completion(nil)
            }
        }
    }
```

Your function will need two parameters -- an array of `Int`s for the ids and a completion handler that receives an optional `JSON`. Assuming anybody can make sense of Swift closures declarations, it should be this:

```swift
    (([Int], ((JSON?) -> Void)) -> Void)
```

To be clear, you write a function that conforms to that, in your code, and it can do whatever you want. The JSON results should map ids to whatever you want, e.g.:

```json
{ "1"=>"This is the content for id 1",
  "2"=>"This is the content for id 2"
}
```

2. Create a batcher for that function and populate it

```swift
import SKBatcher

class ConversationTableViewController : UITableViewController {
	
	var excerptBatcher: SKBatcher

    override func viewDidLoad() {
        super.viewDidLoad()

        excerptBatcher = SKBatcher(apiCall: APICalls.getConversationExcerpts)
    }
}
```

When we have the list of ids, set up the batcher

```swift
func setIds(ids: [Int]) {
	avatarBatcher.allIds = ids
	tableView.reloadData()
}
```

3. When you need to populate a `UITableViewCell`, as the `SKBatcher`

```swift
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let conversationId = conversationIdForIndexPath(indexPath)

        var cell = tableView.dequeueReusableCellWithIdentifier(MyCell.identifier, forIndexPath: indexPath) as? MyCell
        if cell == nil {
            cell = MyCell(identifier: MyCell.identifier)
        }
        cell?.id = conversationId

        // Load avatars from batcher
        cell?.excerpt = "" // Initialize excerpt to empty while it's loading
        exerptBatcher.fetch(conversationId) { excerpt in 
        	// Now we have the excerpt. Make sure the cell hasn't been reused and set it
        	if (cell?.id == conversationId) {
        		cell?.excerpt = (excerpt as? String)
        	}
        } 
```

That's it! SKBatcher will take care of initiating requests for ids that are soon going to be requested. It'll cache results. It'll generally make life easier.


## Status and Next Steps

I wrote `SKBatcher` for the use case described above -- listing an arbitrary number of conversations in a `UITableView`. While writing it, I realized it was naturally turning into something generic and reusable. I haven't yet put much effort into making it truly reusable. Ideally, it would be more configurable and more flexible with the input and output formats. I'd also like to invest time into creating a better example with runnable code.

Potential issues:

- I haven't thought much about thread safety, though I believe it's not an issue
- There may be retain cycles due to the use of stored closures
- Haven't written tests to confirm that caching and pre-loading are correctly working


