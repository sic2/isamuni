require 'FacebookCrawler'
require 'RegionFinder'

class CrawlerJob < ApplicationJob
  queue_as :default

  def initialize(options={})
    options.merge!(app_id: ENV['ISAMUNI_APP_ID'], app_secret: ENV['ISAMUNI_APP_SECRET'])
    @crawler = ::FB::Crawler.new(options)
    @regionfinder = RegionFinder.from_csv 
  end

  def crawlGroup(source, limit=0)
    n_posts = 0
    n_events = 0

    feed = @crawler.group_feed(source.uid, limit)

    feed.each do |element|

      if element.post?
        post = Post.from_fb_post(element)
        post.source = source
        post.save!
        n_posts += 1
      end

      elinks = element.event_links

      if elinks.key? 'fb'
        einfo = @crawler.event_info(elinks['fb'])
        e = Event.from_fb_event(einfo)
        e.province = @regionfinder.from_string(einfo.area_str)
        e.source = source
        e.save!
        n_events += 1
      end

    end

    logger.info "group #{source.name}: inserted/updated #{n_posts} posts, #{n_events} events"
  end

  def crawlPage(source, posts_per_source=0)
    n_events = 0
    
    page_events = @crawler.page_events(source.uid, posts_per_source)

    page_events.each do |element|
      e = Event.from_fb_event(element)
      e.province = @regionfinder.from_string(element.area_str)
      e.source = source
      e.save!
      n_events += 1
    end

    logger.info "page #{source.name}: inserted/updated #{n_events} events"
  end

  def refresh_sources
    count = 0
    Source.where.not(status: :disabled).each do |source|
      begin
        if source.stype == 'group'
          source.from_fb_group @crawler.group_info(source.uid)
        elsif source.stype == 'page'
          source.from_fb_page @crawler.page_info(source.uid)
        end
        count += 1
      rescue => e
        logger.error "error while refreshing source #{source.id}:" + e.message
        source.message = e.message
        source.status = 'disabled'
      end
      source.message = ""
      source.touch
      source.save!
    end
    logger.info "refreshed #{count} sources"
  end

  def perform(posts_per_source=0)
    logger.info 'refreshing sources'
    refresh_sources()

    logger.info "crawling, with #{posts_per_source} posts per source"
    
    Source.where.not(status: :disabled).each do |source|
      logger.info "crawling source: #{source.name}" 

      begin
        if source.stype == 'group'
          crawlGroup(source, posts_per_source)
        elsif source.stype == 'page'
          crawlPage(source)
        else
          raise "Unknown source type"
        end
        
        source.status = 'working'
        source.message = ""
        
      rescue => e
        
        source.status = 'failing'  
        source.message = e.message
        logger.info "error while processing source #{source.id}:" + e.message
        logger.error e.backtrace.join("\n")
      end

      source.last_crawled_at = Time.now
      source.save!

    end

    logger.info 'Done'
  end
end
