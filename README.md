# Data Storytelling with SQL: Customer Segmentation Using RFM Analysis
<img width="687" height="352" alt="Screenshot 2026-02-25 at 11 32 00" src="https://github.com/user-attachments/assets/4ecca710-69fe-4f23-bd55-738bddf52aa1" />

Understanding customer behavior is one of the most valuable things a business can do with its data. In this article, I’ll walk through how I used SQL to perform an RFM analysis. A classic but powerful method for customer segmentation, using transactional data from the TPCH sample dataset in Snowflake.

This project was part of a data analysis course assignment, where the goal was not only to compute metrics, but also to tell a story with data: Who are our best customers? Who is at risk? And how can these insights guide business decisions?

## What Is RFM Analysis?
RFM stands for:

**Recency** — How recently did a customer make a purchase?
**Frequency** — How often do they purchase?
**Monetary Value** — How much revenue do they generate?
By scoring customers on these three dimensions, we can group them into meaningful segments such as Champions, Loyal Customers, or At-Risk Customers, and tailor strategies accordingly.

## Dataset and Scope
I used the following Snowflake sample tables:

**orders** – transactional order data
**customer** – customer attributes
**nation** – customer country information
The dataset’s last available purchase date is 1998–08–02, which I use as a reference point for calculating recency.

Since RFM is inherently transaction-based, I intentionally exclude customers with zero orders from this analysis.

# Part 1: The code (designing the RFM scores and methodology)
## Step 1: Aggregating Customer Order Data
The first step is to aggregate order-level data into one row per customer. This gives us the raw ingredients needed for RFM scoring.

<img width="670" height="305" alt="Screenshot 2026-02-25 at 11 34 55" src="https://github.com/user-attachments/assets/9f859356-39c4-4f09-9420-31e2fbf1f23f" />

At this stage, we already have some useful insights:

- Who orders the most?
- Who generates the most revenue?
- Who hasn’t ordered in a long time?

But to compare customers meaningfully, we need relative scores, not raw numbers.

## Step 2: Assigning RFM Values with Quartiles
To score customers, I use the NTILE(4) window function. This assigns customers into quartiles (1–4) for each RFM dimension.

<img width="661" height="224" alt="Screenshot 2026-02-25 at 11 35 42" src="https://github.com/user-attachments/assets/462c0af6-972c-4e1a-a7cb-b335ce54a2d7" />

## A quick note on Recency
For recency, I sort _days_since_last_order_ in descending order, so customers who purchased more recently receive higher R values.

## Step 3: Calculating a weighted RFM Score
In many RFM models, all three dimensions are weighted equally. However, in this dataset, most customers placed their last order within the final months of 1998.

This means that small differences in recency can create disproportionately large score changes.

To account for this, I intentionally weighted recency lower than frequency and monetary value:

- **Frequency**: 40%
- **Monetary Value**: 40%
- **Recency**: 20%

<img width="669" height="187" alt="Screenshot 2026-02-25 at 11 37 17" src="https://github.com/user-attachments/assets/9c89a4f9-4c9f-49af-8bbf-c249156b144f" />

This makes the final score more stable and better aligned with long-term customer value.

## Step 4: Customer Segmentation
With RFM values and a final score in place, I segment customers into intuitive, business-friendly groups.

<img width="675" height="385" alt="Screenshot 2026-02-25 at 11 38 06" src="https://github.com/user-attachments/assets/e32fd05c-16f7-436a-b6c9-ac611d202db2" />

Each segment tells a story:

- Champions → reward and retain
- Loyal Customers → upsell and engage
- At Risk → reactivation campaigns
- Can Not Lose → high-priority win-back
- Lost Customers → low-cost re-engagement or churn analysis

## Step 5: Final Customer View
Finally, I enrich the RFM data with customer and country information by joining the RFM data with the _customer_ and _nation_ tables.

<img width="650" height="557" alt="Screenshot 2026-02-25 at 11 39 00" src="https://github.com/user-attachments/assets/a04aefa4-9af4-478a-b998-5c28e6009886" />

The final result is saved as _final_cte_ and can easily be viewed like this:

<img width="660" height="164" alt="Screenshot 2026-02-25 at 11 39 30" src="https://github.com/user-attachments/assets/375486b6-588c-43a8-aff7-09b076fb25d6" />

# Part 2: The Analysis
Once the RFM model and customer segments were in place, the next step was to use them to answer concrete business questions. Segmentation on its own is only valuable if it leads to insights and actions.

Below are a few targeted analyses I ran on top of the final RFM table.

## How Are Customers Distributed Across Segments?
First, I wanted to understand the overall composition of the customer base.

<img width="658" height="223" alt="Screenshot 2026-02-25 at 11 40 03" src="https://github.com/user-attachments/assets/0a6ed618-1fad-48d0-9f09-c62dc479c692" />

## The output

<img width="704" height="444" alt="Screenshot 2026-02-25 at 11 40 28" src="https://github.com/user-attachments/assets/b690977a-4d43-4e62-ac9c-1e642a9d506d" />

## Insight
The Loyal Customer segment is by far the largest, with close to 35,000 customers, while New Customers is the smallest segment with just 3,272 customers.

This imbalance suggests a potential acquisition issue. While the business does a good job retaining and nurturing existing customers, the pipeline of newly acquired customers appears relatively weak. Over time, this could become a growth bottleneck.

## Which Segments Generate the Most Revenue?
Customer count alone doesn’t tell the full story, so next I analyzed revenue contribution by segment.

<img width="640" height="237" alt="Screenshot 2026-02-25 at 11 41 07" src="https://github.com/user-attachments/assets/bd594a3b-34c0-48e0-bcd8-c3bf1981e36d" />

## The output

<img width="713" height="448" alt="Screenshot 2026-02-25 at 11 41 50" src="https://github.com/user-attachments/assets/b426c664-94ef-4b96-9811-ce76a229eeb1" />

## Insight
- _Loyal Customers_ generate the highest total revenue
- _At Risk customers_ come in second
- _Champions_ rank third, but unsurprisingly has by far the highest average revenue
- _Can Not Lose_ also contributes a significant share
What stands out here is that At Risk and Can Not Lose customers generate very high revenue, both in total and on average.

This highlights a critical business risk:

**Losing even a small portion of these customers would have a disproportionately large impact on revenue.
**
These segments should be top priority for retention and win-back campaigns.

## Who Are the Top High-Value Customers?
To zoom in further, I identified the top 5 individual customers among what I define as high-value segments:

- _Champion_
- _Loyal Customer_
- _Can Not Lose_

<img width="611" height="280" alt="Screenshot 2026-02-25 at 11 43 49" src="https://github.com/user-attachments/assets/b2d2aa84-51c6-4b9f-8190-561892da7660" />

## Insight
Since Champions naturally score highest on RFM, I added additional ordering criteria — total revenue, number of orders, and recency — to break ties and surface the absolute best customers.

These are the customers a business should:

- Offer exclusive perks
- Assign VIP support
- Use as reference cases for ideal customer behavior

## Where Are High-Value Customers Located?
Finally, I looked at geographic distribution to see which countries have the highest concentration of high-value customers.

<img width="649" height="254" alt="Screenshot 2026-02-25 at 11 44 38" src="https://github.com/user-attachments/assets/841881f1-9c0a-43f8-bfd5-020348b82aba" />

## The output

<img width="637" height="1027" alt="Screenshot 2026-02-25 at 11 45 24" src="https://github.com/user-attachments/assets/63819c3e-c1b2-445e-a443-ebe5fb11d894" />

## Insight

- Russia has the highest number of high-value customers
- Followed by Indonesia and France
- Egypt and Peru have the fewest

This type of analysis opens the door to region-specific strategies:

- Invest more in markets with strong high-value representation
- Investigate whether underperforming regions suffer from product, pricing, or distribution challenges

# Part 3: Final Reflections and Business Takeaways
To conclude this analysis, I want to step back from the SQL itself and reflect on the methodological choices, key drivers of customer behavior, and strategic implications revealed by the RFM model.

## Segment Distribution Insights
Looking at the distribution of customers across segments reveals important structural insights about the business.

Out of approximately 150,000 total registered users , only about 100,000 have ever placed an order. This means roughly 50,000 users are registered but not activated, representing a large untapped opportunity.

Among purchasing customers:

- Only 3,423 fall into the New Customer segment
- Around 24% belong to the Loyal Customer segment

This tells a clear story:
the company has built a strong, loyal customer base, but struggles with activating new users and converting them into buyers. Retention is high, but acquisition is not translating into growth.

## Strategic Recommendations
A deeper look into customer history reinforces this conclusion. An additional analysis shows that only 540 new customers have been acquired since 1995, while nearly all purchasing customers made their first order before that year.

Despite this, daily order volume remains stable over time. Ideally, we would expect this number to increase as the customer base grows. Instead, the business appears to rely heavily on customers who converted many years ago.

From a strategic perspective:

- Acquisition is not the primary issue: the platform has many registered users
- Conversion is the main bottleneck

To address this, leadership and marketing teams should prioritize:

- Stronger activation strategies (e.g. onboarding offers, first-order discounts)
- More targeted marketing toward non-purchasing users
- A review of existing acquisition channels and experimentation with new ones

Improving conversion while maintaining high retention would allow the business to grow without sacrificing its loyal customer base.

## Opportunities for Further Analysis
If this analysis were extended and note based on sample data, my focus would remain on the conversion and retention gap.

Some questions worth exploring include:

- Which countries or markets initially had strong acquisition and conversion, but later declined? How come?
- What distinguishes countries with the highest long-term retention?
- Are there differences in pricing, marketing channels, or customer experience across regions?

The long-term goal would be to increase activation and conversion, while preserving the strong loyalty already present in the customer base.

# Final Words
This project demonstrated how much insight can be extracted from SQL alone when paired with thoughtful modelling and business reasoning. RFM analysis is not just a scoring technique. It is a lens for understanding customer behaviour, identifying risks, and uncovering growth opportunities.

By moving beyond metrics and focusing on interpretation, segmentation becomes a powerful tool for decision-making. This assignment reinforced the importance of connecting data to strategy, and using analysis to tell a story that matters.
