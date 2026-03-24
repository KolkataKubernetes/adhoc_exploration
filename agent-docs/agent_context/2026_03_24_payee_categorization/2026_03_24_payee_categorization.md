## Constructing a categorical variable named payee_type

### Motivation
- Seems like formatted_payee_name has a bunch of corporations, banks, trusts, and farm incorporations, not just individuals
- What I'd like to do is categorize the payees into a few broad categories: Person, Farm_Ranch, Person_Trust, Other

### A few example categories that might be useful, and their associated formatted_payee_name patterns
government:
- "FARM SERVICE AGENCY"
- "USDA"
- "FSA"
- "FARM CREDIT"
- "COMMODITY CREDIT"
-"CCC"

bank/FI":
- "FINANCE"
- "CREDIT UNION"
- "BANK"
Farm Holding Company:
- "FARMS"
- "DAIRY"
- "LLC"
 
### NAME MISCATEGORIZATIONS: SOMETHING TO WATCH OUT FOR DURING IMPLEMENTATION
- I tried implementing some rough code that follows the above regime. The code can be found in '/Users/indermajumdar/Research/adhoc_exploration/agent-docs/agent_context/2026_03_24_payee_categorization/2026_03_24_payee_cat_examplecode.R'
- However, the current categorization regime creates some obvious misses. For example, consider the items below when I filter on geocoded addresses for category bank_fi:
LINDA S BANKS -> Person
JACKIE R & DUFFIE L BANKS JV -> Person
HUGHBANKS RANCH LLC -> Person
ANTHONY JASON MARCHBANKS -> Person
STANLEY EUBANKS -> Person
LEROY EUBANK -> Person
BRIAN EUBANK -> Person
KELBY C EUBANK -> Person
EMMA L BURBANK -> Person
KIM A BANKSON-> Person
MARILYN BANKS -> Person
JUSTIN EUBANK -> Person
JOSH EUBANK -> Person
DAVID D BANKS -> Person
FAIRBANKS BAPTIST CHURCH
THOMAS J BROOKBANK -> Person
BRIAN BROOKBANK -> Person
TIMOTHY AARON BROOKBANK -> Person
BRADLEY J FAIRBANKS -> Person
LLOYD D BANK -> Person
DOUGLAS A FAIRBANKS -> Person
RANDY EUBANK -> Person
JOAN MARIE EUBANKS -> Person
RONALD T BANKS -> Person
JOHN LELAND BANKS -> Person
RAY JOSEPH BANKS -> Person
TAYLOR JOHN BANKS -> Person
GALEN BANKS -> Person
KEVIN A BANKS -> Person
DANNY EUBANK -> Person
DALEBANKS ANGUS INC -> Farm_Ranch
KATHERINE A FAIRBANKS -> Person
FRANK A EUBANK -> Person
DONALD J EUBANKS AND MARIE F EUBA -> Person
DONALD W NEWBANKS REVOCABLE TRUST -> Person_Trust
KINGS BANK FARM LLC -> Farm_Ranch
WALTER E BANKER TRUST 1 -> Person_Trust
JAMES L BANKS -> Person
THOMAS C BANKS III -> Person
THOMAS BANKS JR -> Person
LARRY BANKS -> Person
GLYNN E BANKS -> Person
CLAUDIA BANKS -> Person
BANKSTON UDDER-WISE DAIRY INC -> Farm_Ranch
ANDY BANKSTON -> Person
BANKS FARMS INC -> Farm_Ranch
- These should clearly not be categorized as banks or financial institutions
- 
## PLAN OF WORK
- First, let's find a data-driven way to propose 3-5 categories that are relevant for further economic analysis. I'm hoping that these categories can provide insight into the "type" of payee. Is it a person? Personal trust? Bank? Private financial institution? Government financial institution? Other government entity?
- Then let's implement code that categorizes each of the rows accordingly. 
- Remember that I want to keep code simple; Dplyr/Tidyverse packages, commented, and let's avoid excessive use of helper functions where necessary.
